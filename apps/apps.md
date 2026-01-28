# Applications

| Unikernel & Sources | Description |
|--------------------|-------------|
| [DHCP server](https://github.com/crossbowerbt/dhcpserver) | A stand-alone DHCP server. |
| [DNS server](https://github.com/samboy/MaraDNS) | An authoritative DNS server ported as a unikernel. We modified it to stop just before the `accept()` function to simulate ephemeral unikernels. |
| [FTP server](https://github.com/rovinbhandari/FTP) | An FTP server ported as a unikernel. |
| [Haproxy](https://github.com/haproxy/haproxy) | The Haproxy server ported as a unikernel (community edition). |
| [Helloworld](https://github.com/unikraft/app-helloworld) | A simple “Hello World!” unikernel used for testing and demonstration purposes. |
| [Httpreply](https://github.com/unikraft/app-httpreply) | A minimal HTTP server, useful for testing basic web server functionality. |
| [Iperf3](https://github.com/esnet/iperf/tree/master/src) | The Iperf3 performance network tool server ported as a unikernel. |
| [Lambda-perf](https://github.com/gaulthiergain/apps/blob/main/lambda/main.c) | Reads an image, performs a 2× up-scaling transformation, and writes the result. |
| [Mandelbrot-perf](https://github.com/amenzwa/mandelbrot/blob/main/mandelbrot.c) | A Mandelbrot generator saving a 1280×720 image with 10 000 iterations. |
| [Matrix-perf](https://github.com/gaulthiergain/apps/blob/main/matrix/main.c) | A parallel 2000×2000 matrix multiplier saving the result to a file. |
| [Nginx](https://github.com/unikraft/catalog/tree/main/library/nginx) | The Nginx web server ported as a unikernel. We modified it to stop just before the `accept()` function to simulate ephemeral unikernels. |
| [NTP server](https://github.com/ddrown/pretend-ntp) | An NTP server ported as a unikernel. |
| [Proxy server](https://github.com/aarond10/https_dns_proxy) | A lightweight DNS-to-HTTPS proxy for the RFC 8484 DNS-over-HTTPS standard. |
| [Scamper-uradargun](https://github.com/YvesVanaubel/TNT/blob/master/TNT/scamper-tnt-cvs-20180523a/utils/sc_radargun/sc_radargun.c) | Scamper driver to run radargun on a list of candidate aliases. |
| [Scamper-uspeedtrap](https://github.com/YvesVanaubel/TNT/blob/master/TNT/scamper-tnt-cvs-20180523a/utils/sc_speedtrap/sc_speedtrap.c) | Scamper driver to resolve aliases for a set of IPv6 interfaces. |
| [Scamper-utnt](https://github.com/YvesVanaubel/TNT/blob/master/TNT/scamper-tnt-cvs-20180523a/utils/sc_tnt/sc_tnt.c) | Scamper driver to reveal MPLS tunnels to a destination. |
| [SQLite](https://github.com/unikraft/catalog/tree/main/library/sqlite/3.40) | The SQLite shell ported as a unikernel. |
| [SQLite-perf](https://github.com/sqlite/sqlite/blob/master/test/speedtest1.c) | The SQLite speed test ported as a unikernel. |
| [Weborf](https://github.com/ltworf/weborf) | The Weborf web server ported as a unikernel. |
| [Zlib-perf](https://github.com/madler/zlib/blob/master/examples/zpipe.c) | A zlib-based unikernel that inflates and deflates a 10 MiB file. |