# Applications

| Unikernel & Sources | Description |
|--------------------|-------------|
| [Helloworld](https://github.com/unikraft/app-helloworld) | A simple “Hello World!” unikernel used for testing and demonstration purposes. |
| [Lambda-perf](https://github.com/gaulthiergain/apps/blob/main/lambda/main.c) | Reads an image, performs a 2× up-scaling transformation, and writes the result. |
| [Mandelbrot-perf](https://github.com/amenzwa/mandelbrot/blob/main/mandelbrot.c) | A Mandelbrot generator saving a 1280×720 image with 10 000 iterations. |
| [Nginx](https://github.com/unikraft/catalog/tree/main/library/nginx) | The Nginx web server ported as a unikernel. We modified it to stop just before the `accept()` function to simulate ephemeral unikernels. |
| [Python FaaS](https://github.com/unikraft/app-python3) | A Python-based lambda FaaS |
| [SQLite-perf](https://github.com/sqlite/sqlite/blob/master/test/speedtest1.c) | The SQLite speed test ported as a unikernel. |
| [Zlib-perf](https://github.com/madler/zlib/blob/master/examples/zpipe.c) | A zlib-based unikernel that inflates and deflates a 10 MiB file. |