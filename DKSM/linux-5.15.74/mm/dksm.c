#include <linux/mm.h>
#include <linux/pagewalk.h>
#include <linux/pagemap.h>
#include <linux/list.h>
#include <linux/hashtable.h>
#include <linux/xxhash.h>
#include <linux/rmap.h>
#include <linux/mmu_notifier.h>
#include <linux/swap.h>
#include <linux/fs.h>
#include <linux/sysfs.h>
#include <linux/kobject.h>
#include <linux/mman.h>
#include <linux/mutex.h>
#include <linux/dksm.h>

#include <asm/tlbflush.h>
#include "internal.h"

#define DEBUG 0

#define DKSM_RUN_STOP	0
#define DKSM_RUN_MERGE	1

// DKSM is off by default
static unsigned long dksm_run = DKSM_RUN_STOP;

static DEFINE_MUTEX(dksm_mutex);

struct page_descriptor {
    u32 checksum;
    unsigned long pfn;
    unsigned long vaddr;
    struct hlist_node pd_list;
};

struct page_walk_data {
    unsigned long pages_scanned;
    unsigned long pages_merged;
    unsigned long merging_failed;
    unsigned long htable_size;
    DECLARE_HASHTABLE(hashtable, 12);
};

static inline u32 calc_checksum(struct page *page)
{
	u32 checksum;
	void *addr = kmap_local_page(page);
	checksum = xxhash(addr, PAGE_SIZE, 0);
	kunmap_local(addr);
	return checksum;
}

static int replace_page(struct vm_area_struct *vma, struct page *page,
			            struct page *kpage, pte_t orig_pte)
{
	struct mm_struct *mm = vma->vm_mm;
	pmd_t *pmd;
	pte_t *ptep;
	pte_t newpte;
	unsigned long addr;
	int err = -EFAULT;
	struct mmu_notifier_range range;

	addr = page_address_in_vma(page, vma);
	if (addr == -EFAULT) {
        printk(KERN_ERR "[DKSM] replace_page: vma address\n");
		goto out;
    }

	pmd = mm_find_pmd(mm, addr);
	if (!pmd) {
        printk(KERN_ERR "[DKSM] replace_page: find pmd\n");
		goto out;
    }

	mmu_notifier_range_init(&range, MMU_NOTIFY_CLEAR, 0, vma, mm, addr,
				addr + PAGE_SIZE);
	mmu_notifier_invalidate_range_start(&range);

	ptep = pte_offset_map(pmd, addr);
    
	if (!pte_same(*ptep, orig_pte)) {
        printk(KERN_ERR "[DKSM] replace_page: different pte\n");
		pte_unmap(ptep);
		goto out_mn;
	}

    get_page(kpage);
    page_add_anon_rmap(kpage, vma, addr, false);
    newpte = mk_pte(kpage, vma->vm_page_prot);

	flush_cache_page(vma, addr, pte_pfn(*ptep));

	ptep_clear_flush(vma, addr, ptep);
	set_pte_at_notify(mm, addr, ptep, newpte);

	page_remove_rmap(page, false);
	if (!page_mapped(page))
		try_to_free_swap(page);
	put_page(page);

    pte_unmap(ptep);
	err = 0;
out_mn:
	mmu_notifier_invalidate_range_end(&range);
out:
	return err;
}

static inline void remove_pd(struct page_descriptor *pd, struct page_walk_data *pwd)
{
    hash_del(&pd->pd_list);
    kfree(pd);
    pwd->htable_size--;
}

static int page_cmp_and_merge(pte_t *pte, unsigned long addr,
			                  unsigned long next, struct mm_walk *walk)
{
    pteval_t pte_fgs;
    unsigned int checksum;
    struct page_descriptor *pd;
    struct page *curr_page, *old_page;
    struct page_descriptor *iter;
    struct hlist_node *tmp;

    int err = 0;
    bool merged = false;
    struct page_walk_data *pwd = walk->private;
    pte_fgs = pte_flags(*pte);
    
    if (DEBUG)
        printk(KERN_DEBUG "[DKSM] page_cmp_and_merge called\n");

    if (!pte_present(*pte)) {
        printk(KERN_ERR "[DKSM] pte not present\n");
        pwd->merging_failed++;
        return 0;
    }

    if (!pte_access_permitted(*pte, 0)) {
        printk(KERN_ERR "[DKSM] pte access not permitted\n");
        pwd->merging_failed++;
        return 0;
    }

    if (DEBUG) {
        if(pte_write(*pte)) {
            printk(KERN_DEBUG "[DKSM] page is writable\n");
            // only read-only pages are advertised, proceed
        }
    }

    curr_page = pte_page(*pte);

    if (!PageAnon(curr_page)) {
        printk(KERN_ERR "[DKSM] page not anonymous\n");
        pwd->merging_failed++;
        return 0;
    }

    if (PageTransCompound(curr_page)) {
        printk(KERN_ERR "[DKSM] page is transparant huge\n");
        pwd->merging_failed++;
        return 0;
    }

    pd = kmalloc(sizeof(struct page_descriptor), GFP_KERNEL);
    if (pd == NULL) {
        printk(KERN_ERR "[DKSM] kmalloc failed\n");
        pwd->merging_failed++;
        return -ENOMEM;
    }

    checksum = calc_checksum(curr_page);
    pd->checksum = checksum;
    pd->pfn = page_to_pfn(curr_page);
    pd->vaddr = addr;

    pwd->pages_scanned++;

    hash_for_each_possible_safe(pwd->hashtable, iter, tmp, pd_list, checksum) {
        if (iter->checksum != checksum) {
            if (DEBUG)
                printk(KERN_DEBUG "[DKSM] hashtable collision\n");
            continue;
        }

        old_page = pfn_to_page(iter->pfn);
        if (!get_page_unless_zero(old_page)) {
            if (DEBUG)
                printk(KERN_DEBUG "[DKSM] old page has been freed\n");

            // old_page cannot be found, remove it from hashtable
            remove_pd(iter, pwd);
            continue;
        }

        if (unlikely(calc_checksum(old_page) != iter->checksum)) {
            if (DEBUG)
                printk(KERN_DEBUG "[DKSM] old page changed\n");
            put_page(old_page);

            // old_page has changed, remove it from hashtable
            remove_pd(iter, pwd);
            continue;
        }

        if (pages_identical(curr_page, old_page)) {

            if (DEBUG) {            
                printk(KERN_DEBUG "[DKSM] try to merge:\n\t pfn: %lx %lx\n\tvaddr: %lx %lx\n\t\
                    refs: %d %d\n\t checksums: %u\n",\
                    pd->pfn, iter->pfn, addr, iter->vaddr,\
                    page_ref_count(curr_page), page_ref_count(old_page),\
                    checksum);
            }

            // curr_page is freed in replace_page
            err = replace_page(walk->vma, curr_page, old_page, *pte);
            put_page(old_page);
            if (err) {
                if (DEBUG)
                    printk(KERN_DEBUG "[DKSM] replace_page failed\n");
                pwd->merging_failed++;
            } else {
                pwd->pages_merged++;
                merged = true;
                goto out;
            }
        } else {
            put_page(old_page);
        }
    }

out:
    if (merged) {
        kfree(pd);
    } else {
        hash_add(pwd->hashtable, &pd->pd_list, checksum);
        pwd->htable_size++;
    }

    return 0;
}

static const struct mm_walk_ops page_walk_ops = {
	.pte_entry		= page_cmp_and_merge,
};

static struct page_walk_data* pwd = NULL;

#ifdef CONFIG_SYSFS

#define DKSM_ATTR_RO(_name) \
	static struct kobj_attribute _name##_attr = __ATTR_RO(_name)
#define DKSM_ATTR(_name) \
	static struct kobj_attribute _name##_attr = \
		__ATTR(_name, 0644, _name##_show, _name##_store)

static ssize_t run_show(struct kobject *kobj, struct kobj_attribute *attr,
			char *buf)
{
	return sysfs_emit(buf, "%lu\n", dksm_run);
}

static ssize_t run_store(struct kobject *kobj, struct kobj_attribute *attr,
			             const char *buf, size_t count)
{
	int err;
    unsigned int flags;
    int bkt;
    struct hlist_node *tmp;
    struct page_descriptor *iter;

    if (pwd == NULL) {
        return count;
    }

	err = kstrtouint(buf, 10, &flags);
	if (err)
		return -EINVAL;
	if (flags > DKSM_RUN_MERGE)
		return -EINVAL;

    mutex_lock(&dksm_mutex);
    if (dksm_run != flags) {
        dksm_run = flags;
        if (dksm_run == DKSM_RUN_STOP) {
            if (DEBUG)
                printk(KERN_DEBUG "[DKSM] purging hashtable\n");
            
            hash_for_each_safe(pwd->hashtable, bkt, tmp, iter, pd_list) {
                hash_del(&iter->pd_list);
                kfree(iter);
            }
            pwd->pages_scanned = 0;
            pwd->pages_merged = 0;
            pwd->merging_failed = 0;
            pwd->htable_size = 0;
        }
    }
    mutex_unlock(&dksm_mutex);

    return count;
}
DKSM_ATTR(run);

static ssize_t pages_scanned_show(struct kobject *kobj, struct kobj_attribute *attr, char *buf)
{
    unsigned long val;
    if (pwd == NULL) {
        val = 0;
    } else {
        val = pwd->pages_scanned;
    }
    return sysfs_emit(buf, "%lu\n", val);
}
DKSM_ATTR_RO(pages_scanned);

static ssize_t pages_merged_show(struct kobject *kobj, struct kobj_attribute *attr, char *buf)
{
    unsigned long val;
    if (pwd == NULL) {
        val = 0;
    } else {
        val = pwd->pages_merged;
    }
    return sysfs_emit(buf, "%lu\n", val);
}
DKSM_ATTR_RO(pages_merged);

static ssize_t merging_failed_show(struct kobject *kobj, struct kobj_attribute *attr, char *buf)
{
    unsigned long val;
    if (pwd == NULL) {
        val = 0;
    } else {
        val = pwd->merging_failed;
    }
    return sysfs_emit(buf, "%lu\n", val);
}
DKSM_ATTR_RO(merging_failed);

static ssize_t hashtable_entries_show(struct kobject *kobj, struct kobj_attribute *attr, char *buf)
{
    unsigned long val;
    if (pwd == NULL) {
        val = 0;
    } else {
        val = pwd->htable_size;
    }

    return sysfs_emit(buf, "%lu\n", val);
}
DKSM_ATTR_RO(hashtable_entries);

static ssize_t hashtable_size_show(struct kobject *kobj, struct kobj_attribute *attr, char *buf)
{
    unsigned long val;
    if (pwd == NULL) {
        val = 0;
    } else {
        val = ARRAY_SIZE(pwd->hashtable);
    }
    return sysfs_emit(buf, "%lu\n", val);
}
DKSM_ATTR_RO(hashtable_size);

static struct attribute *ksm_attrs[] = {
	&run_attr.attr,
	&pages_scanned_attr.attr,
	&pages_merged_attr.attr,
	&merging_failed_attr.attr,
	&hashtable_entries_attr.attr,
	&hashtable_size_attr.attr,
	NULL,
};

static const struct attribute_group dksm_attr_group = {
	.attrs = ksm_attrs,
	.name = "dksm",
};

#endif /* CONFIG_SYSFS */

int dksm_madvise(struct vm_area_struct *vma, unsigned long start,
		         unsigned long end, int advice, unsigned long *vm_flags)
{
	int err = 0;
    const struct mm_walk_ops *ops;

    if (DEBUG)
        printk(KERN_DEBUG "[DKSM] dksm_madvise called\n");

    if (unlikely(pwd == NULL)) {
        mutex_lock(&dksm_mutex);
        pwd = kmalloc(sizeof(struct page_walk_data), GFP_KERNEL);
        if (pwd == NULL) {
            printk(KERN_ERR "[DKSM] pwd kmalloc failed\n");
            return -ENOMEM;
        }
        pwd->pages_scanned = 0;
        pwd->pages_merged = 0;
        pwd->merging_failed = 0;
        pwd->htable_size = 0;
        hash_init(pwd->hashtable);
        mutex_unlock(&dksm_mutex);
    }

    if (advice != MADV_MERGEABLE) {
        if (DEBUG)
            printk(KERN_DEBUG "[DKSM] MADV_UNMERGEABLE ignored\n");
		return 0;
	}
    
    ops = &page_walk_ops;

    if (DEBUG)
	    printk(KERN_DEBUG "[DKSM] page_walk start:%lx, end:%lx\n", start, end);

    mutex_lock(&dksm_mutex);
    if (dksm_run == DKSM_RUN_MERGE) {

        // mmap_read_lock already locked by madvise
        err = walk_page_range(vma->vm_mm, start, end, ops, pwd);

        mutex_unlock(&dksm_mutex);
        if (err) {
            printk(KERN_ERR "[DKSM] walk_page_range failed\n");
            return err;
        }
    } else {
        mutex_unlock(&dksm_mutex);
        if (DEBUG)
            printk(KERN_DEBUG "[DKSM] DKSM is disabled\n");
    }

    if (DEBUG) {
	    printk(KERN_DEBUG "[DKSM] total scanned pages: %lu\n", pwd->pages_scanned);
	    printk(KERN_DEBUG "[DKSM] total merged pages: %lu\n", pwd->pages_merged);
	    printk(KERN_DEBUG "[DKSM] total failed merging: %lu\n", pwd->merging_failed);
        printk(KERN_DEBUG "[DKSM] number of hashtable entries: %lu\n", pwd->htable_size);
    }

    return 0;
}

static int __init dksm_init(void)
{
    int err = 0;
	printk(KERN_DEBUG "[DKSM] initializing\n");

	pwd = kmalloc(sizeof(struct page_walk_data), GFP_KERNEL);
	if (pwd == NULL) {
		printk(KERN_ERR "[DKSM] pwd kmalloc failed\n");
		return -ENOMEM;
	}
	pwd->pages_scanned = 0;
	pwd->pages_merged = 0;
	pwd->merging_failed = 0;
	pwd->htable_size = 0;
	hash_init(pwd->hashtable);

#ifdef CONFIG_SYSFS
	err = sysfs_create_group(mm_kobj, &dksm_attr_group);
	if (err) {
		pr_err("[DKSM] register sysfs failed\n");
	}
#else
	dksm_run = DKSM_RUN_MERGE;
#endif /* CONFIG_SYSFS */

	return err;
}
subsys_initcall(dksm_init);