/*
gcc -nostdlib -ffreestanding -nostdinc -fPIC -shared libukconstructors.c -Wl,-T,/home/gain/dev/unikraft_dynamic/apps/appnginx-perf/build/liblinuxuplat/link64.lds -Wl,-T,/home/gain/dev/unikraft_dynamic/unikraft/lib/vfscore/extra.ld -Wl,-T,/home/gain/dev/unikraft_dynamic/unikraft/lib/posix-socket/driver_list.ld -o libukconstructors.so
sudo cp /home/gain/dev/unikraft_dynamic/elf_loader_c/libukconstructors.so /lib/x86_64-linux-gnu/
*/


__thread unsigned long _uk_syscall_return_addr __attribute__((weak));

void *__uk_sched_thread_current __attribute__((weak));

int vfscore_nullop(){
    return 0;
}

int vfscore_vop_nullop(){
    return 0;
}

int vfscore_vop_einval()
{
	return 0;
}

int vfscore_vop_eperm()
{
	return 0;
}

int vfscore_vop_erofs()
{
	return 0;
}

int my_var __attribute__((section(".data"))) = 42;


void uk_constructors(){
    return my_var;
}