#define SYS_write 1

int main() __attribute__ ((aligned (0x1000)));
void exit_lib(int status);

__attribute__((force_align_arg_pointer))
void _start() {

    /* main body of program: call main(), etc */
    main();

    /* exit system call */
    exit_lib(1);
    __builtin_unreachable();  // tell the compiler to make sure side effects are done before the asm statement
}

int write(int fd, const char *buf, int length)
{
  int ret;
    __asm volatile (
        "syscall"
        : "=a"(ret)
        : "a"(SYS_write), "D"(fd), "S"(buf), "d"(length)
        : "rcx", "r11", "memory"
    );
    return ret;
}

void exit_lib(int status){
    asm("mov $60,%rax; mov $0,%rdi; syscall");
}

int main() 
{
    write(1, "hello\n", 6);
    //fprintf(stdout, "Hello world! fprintf=%p, stdout=%p\n", fprintf, stdout);
    return 0;
}