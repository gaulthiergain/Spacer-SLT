/* SPDX-License-Identifier: GPL-2.0 */
#ifndef __LINUX_DKSM_H
#define __LINUX_DKSM_H


#ifdef CONFIG_DKSM
int dksm_madvise(struct vm_area_struct *vma, unsigned long start,
		unsigned long end, int advice, unsigned long *vm_flags);

#else  /* !CONFIG_KSM */

#ifdef CONFIG_MMU
static inline int dksm_madvise(struct vm_area_struct *vma, unsigned long start,
		unsigned long end, int advice, unsigned long *vm_flags)
{
	return 0;
}

#endif /* CONFIG_MMU */
#endif /* !CONFIG_DKSM */

#endif /* __LINUX_DKSM_H */
