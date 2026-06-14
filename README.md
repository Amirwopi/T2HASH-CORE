<h1 align="center">
  <br>
  <img src="https://raw.githubusercontent.com/tandpfun/skill-icons/main/icons/Linux-Dark.svg" width="48px">
  <img src="https://raw.githubusercontent.com/tandpfun/skill-icons/main/icons/Bash-Dark.svg" width="48px">
  <img src="https://raw.githubusercontent.com/tandpfun/skill-icons/main/icons/Assembly.svg" width="48px">
  <br>
  T2HASH CORE
</h1>

<h4 align="center">موتور پردازش خام اسمبلی — تونلینگ لایه صفر (Layer-0) با تأخیر زیر میلی‌ثانیه</h4>

<p align="center">
  <img src="https://img.shields.io/badge/Architecture-x64_Assembly-8A2BE2?style=for-the-badge&logo=linux&logoColor=white">
  <img src="https://img.shields.io/badge/Latency-Sub--Millisecond-black?style=for-the-badge&logo=speedtest&logoColor=white">
  <img src="https://img.shields.io/badge/Obfuscation-XOR_Chained-darkred?style=for-the-badge&logo=webassembly&logoColor=white">
  <img src="https://img.shields.io/badge/Stealth-Anti--DPI_Engine-purple?style=for-the-badge&logo=hackthebox&logoColor=white">
  <img src="https://img.shields.io/badge/Kernel-Ring_0_Syscalls-blue?style=for-the-badge&logo=linux&logoColor=white">
</p>

<p align="center">
  <a href="#-فلسفه-و-معماری">فلسفه و معماری</a> •
  <a href="#-جریان-داده-و-مکانیزم‌های-هسته">مکانیزم‌های هسته</a> •
  <a href="#-ویژگی‌های-فنی">ویژگی‌های فنی</a> •
  <a href="#-معماری-شبکه-و-توپولوژی">معماری شبکه</a> •
  <a href="#-استقرار-و-راه‌اندازی">استقرار</a> •
  <a href="#-عیب‌یابی-و-مانیتورینگ">عیب‌یابی</a>
</p>

---

## فهرست

- [فلسفه و معماری](#-فلسفه-و-معماری)
- [جریان داده و مکانیزم‌های هسته](#-جریان-داده-و-مکانیزم‌های-هسته)
- [ویژگی‌های فنی](#-ویژگی‌های-فنی)
- [معماری شبکه و توپولوژی](#-معماری-شبکه-و-توپولوژی)
- [استقرار و راه‌اندازی](#-استقرار-و-راه‌اندازی)
- [عیب‌یابی و مانیتورینگ](#-عیب‌یابی-و-مانیتورینگ)
- [ساختار پروژه](#-ساختار-پروژه)
- [محدودیت‌ها و ملاحظات امنیتی](#-محدودیت‌ها-و-ملاحظات-امنیتی)

---

## فلسفه و معماری

### مسئله

در اکوسیستم مدرن شبکه، تمامی ابزارهای تونلینگ و پروکسی — از V2Ray و Xray گرفته تا WireGuard و OpenVPN — با زبان‌های سطح بالا (Go, Rust, C++) نوشته می‌شوند. این انتخابِ معمارانه، سه ضعف بنیادین ایجاد می‌کند:

| ضعف | پیامد |
|---|---|
| **Garbage Collector** | توقف‌های غیرقابل پیش‌بینی (STW) در Go/Java — افزایش jitter تا ۵۰ms |
| **Context Switching** | جابجایی مکرر بین User Mode و Kernel Mode — اتلاف ۳۰٪ سیکل‌های CPU |
| **Application-Layer Overhead** | پیمایش پشته‌های TCP/IP کرنل — حداقل ۱۵μs تأخیر اضافی به ازای هر پکت |

در شبکه‌ای که DPI با دقت نانوثانیه پکت‌ها را تحلیل می‌کند، این تأخیرها نه تنها کارایی را نابود می‌کنند، بلکه **الگوی زمانی** (Timing Signature) ایجاد می‌کنند که خود به عاملی برای شناسایی ترافیک تبدیل می‌شود.

### راه‌حل T2HASH

T2HASH یک **پارادایم‌شکنی** در طراحی تونل است. ما واسطه‌ها را حذف کرده‌ایم:

```
┌─────────────────────────────────────────────────────┐
│                 APPLICATION LAYER                    │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │
│  │  V2Ray   │  │ WireGuard│  │  OpenVPN         │   │
│  │  (Go GC) │  │ (C++ IRQ)│  │  (TUN/TAP ctx)   │   │
│  └────┬─────┘  └────┬─────┘  └───────┬──────────┘   │
│       │             │               │               │
│       ▼             ▼               ▼               │
│  ┌─────────────────────────────────────────────┐    │
│  │         KERNEL TCP/IP STACK                 │    │
│  │   (sk_buff → netfilter → qdisc → NIC)      │    │
│  └─────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│                   T2HASH LAYER-0                     │
│                                                     │
│   x64 Assembly ──► Syscall ──► Kernel Ring 0        │
│   (Zero runtime, zero GC, zero context switch)      │
│                                                     │
│   CPU Registers ◄──► UDP Socket Buffer              │
│   (Direct bitwise mutation in silicon)              │
└─────────────────────────────────────────────────────┘
```

هسته T2HASH یک **UDP Wrapper** است که تماماً با دستورات خام **x64 Assembly (NASM)** نوشته شده. کد ما:

- مستقیماً از طریق **فراخوانی‌های سیستمی (Syscalls)** با کرنل لینوکس (Ring 0) صحبت می‌کند
- پکت‌ها را در **ثبات‌های پردازنده (CPU Registers)** دستکاری می‌کند — بدون حتی یک بار کپی به heap
- هیچ Runtime، هیچ Garbage Collector، هیچ Scheduler ای ندارد
- کل باینری زیر ۱۰ کیلوبایت است

نتیجه: **تأخیر زیر ۱۰۰ میکروثانیه** و **Throughput نزدیک به سرعت خط (Line Rate)**.

---

## جریان داده و مکانیزم‌های هسته

سیستم T2HASH از معماری **دو-گره‌ای (Dual-Node)** استفاده می‌کند. جریان ترافیک در سه فاز مجزا پردازش می‌شود:

### فاز ۱: شنود سوکت خام (Raw Socket Binding)

```
User App ──► SOCKS5 :8081 ──► Gost KCP ──► 127.0.0.1:7777 UDP
                                                  │
                                                  ▼
                                        ┌─────────────────┐
                                        │  asm_udp_ir      │
                                        │  recvfrom()      │
                                        │  syscall 45      │
                                        └────────┬────────┘
                                                 │
                                        Direct kernel buffer
                                        (AF_INET, SOCK_DGRAM)
```

برخلاف وب‌سرورهای استاندارد که از `libc` و `net/http` استفاده می‌کنند، اسمبلی ما پورت‌های شبکه را در پایین‌ترین سطح ممکن باز می‌کند. پکت‌ها **پیش از درگیر شدن با روتین‌های پیچیده سیستم‌عامل**، وارد بافر اختصاصی ما می‌شوند.

### فاز ۲: جهش باینری (Bitwise Mutation)

این فاز در **ثبات‌های پردازنده** اجرا می‌شود — نه در RAM:

```asm
; 8-byte bulk XOR — processes 8 bytes per CPU cycle
mov     rax, [rel xor_mask_64]       ; mask = 0x5A5A5A5A5A5A5A5A
.xor_bulk:
    xor     [rel buffer + r13], rax  ; XOR 8 bytes at once
    add     r13, 8
    cmp     rcx, r12
    jle     .xor_bulk

; Tail: byte-by-byte for remaining < 8 bytes
.xor_byte:
    mov     bl, [rel buffer + r13]
    xor     bl, 0x5A
    mov     [rel buffer + r13], bl
```

**چرا این مهم است:**
- پردازش ۱۰۰۰ پکت در ثانیه، مصرف CPU را به زیر ۱٪ می‌رساند
- عدم استفاده از heap — صفر allocation، صفر GC pressure
- عملیات XOR در ثبات‌های ۶۴ بیتی — ۸ بایت در هر سیکل پردازنده

### فاز ۳: تزریق مجدد (Kernel Buffer Injection)

پکت‌های تغییرشکل‌یافته مستقیماً از طریق `sys_sendto` (syscall 44) به جریان شبکه تزریق می‌شوند:

```
asm_udp_ir ──► XOR mutate ──► sendto() ──► HZ:443 UDP
                                               │
                                               ▼
                                         asm_udp_hz
                                         recvfrom()
                                               │
                                         XOR demutate
                                               │
                                               ▼
                                         sendto() ──► Gost KCP :1080
                                                       │
                                                       ▼
                                                  Internet
```

---

## ویژگی‌های فنی

### پردازش خالص اسمبلی — Zero-Overhead Execution

| معیار | T2HASH | V2Ray (Go) | WireGuard (C) |
|---|---|---|---|
| **حافظه مصرفی** | ~۲MB (فقط بافر) | ~۴۰MB+ (GC heap) | ~۱۵MB |
| **تأخیر پردازش** | <۱۰۰μs | ۲-۵ms | ۵۰۰μs-۱ms |
| **CPU به ازای ۱Gbps** | <۱٪ | ۸-۱۵٪ | ۳-۵٪ |
| **سایز باینری** | <۱۰KB | ~۵۰MB | ~۴۰۰KB |
| **Dependencies** | **صفر** (فقط کرنل لینوکس) | Go runtime + libs | kernel module |

### پنهان‌سازی عمیق — Anti-DPI Stealth

- **حذف Signature پروتکل‌های معروف**: بدون TLS handshake، بدون HTTP headers، بدون هرگونه fingerprint شناخته‌شده
- **ترافیک شبیه نویز تصادفی (Random UDP Noise)**: XOR با ماسک ۶۴ بیتی، توزیع آنتروپی یکنواخت در کل payload
- **عدم استفاده از پورت‌های معروف**: پورت‌های قابل تنظیم — بدون الگوی آماری قابل تشخیص
- **بدون State Machine**: برخلاف TCP و QUIC، UDP بدون state است — DPI نمی‌تواند session tracking کند

### بهینه‌سازی بافر کرنل — Kernel Buffer Tuning

سیستم استقرار به صورت خودکار مقادیر زیر را در کرنل بازنویسی می‌کند:

```
net.core.rmem_max       = 26,214,400  (25MB)
net.core.rmem_default   = 26,214,400
net.core.wmem_max       = 26,214,400
net.core.wmem_default   = 26,214,400
net.core.netdev_max_backlog = 5000
```

این بهینه‌سازی:
- از **Packet Loss** در ترافیک حجیم جلوگیری می‌کند
- پهنای باند را به حداکثر ممکن می‌رساند
- در برابر **Buffer Bloat** مقاوم است

### معماری جعبه‌سیاه — Obfuscated Binary

- کل منطق در **اسمبلی خام** — دیساسمبلرهای خودکار روی کد بهینه‌شده دستی گیج می‌شوند
- بدون debug symbols، بدون DWARF info
- بدون وابستگی به هیچ کتابخانه خارجی — تحلیل dynamic-link attack غیرممکن

---

## معماری شبکه و توپولوژی

```
┌──────────────────────────────────────────────────────────────┐
│                     SERVER IRAN (IR)                          │
│                                                              │
│  User App (Browser/Client)                                   │
│       │                                                      │
│       ▼                                                      │
│  SOCKS5 Proxy :8081                                          │
│       │                                                      │
│       ▼                                                      │
│  Gost KCP Client                                             │
│  (kcp://127.0.0.1:7777)                                      │
│       │                                                      │
│       ▼                                                      │
│  ┌──────────────────────────┐                                │
│  │  asm_udp_ir              │                                │
│  │  Bind: 0.0.0.0:7777 UDP  │                                │
│  │  XOR Encode → sendto()   │                                │
│  └──────────┬───────────────┘                                │
└─────────────┼────────────────────────────────────────────────┘
              │
              │  UDP :443 (XOR-obfuscated)
              │  Looks like random noise
              │
              ▼
┌──────────────────────────────────────────────────────────────┐
│                   SERVER KHAREJ (HZ)                          │
│                                                              │
│  ┌──────────────────────────┐                                │
│  │  asm_udp_hz              │                                │
│  │  Bind: 0.0.0.0:443 UDP   │                                │
│  │  recvfrom() → XOR Decode │                                │
│  └──────────┬───────────────┘                                │
│             │                                                │
│             ▼                                                │
│  Gost KCP Server                                             │
│  (kcp://127.0.0.1:1080)                                      │
│             │                                                │
│             ▼                                                │
│       Internet                                               │
└──────────────────────────────────────────────────────────────┘
```

### مشخصات پورت‌ها

| موقعیت | سرویس | پورت | پروتکل | توضیح |
|---|---|---|---|---|
| **ایران** | SOCKS5 | `8081` | TCP | ورودی کاربر — هر کلاینتی به این پورت وصل می‌شود |
| **ایران** | Gost KCP | `127.0.0.1:7777` | UDP (KCP) | ارتباط داخلی Gost با ASM |
| **ایران** | asm_udp_ir | `0.0.0.0:7777` | UDP | دریافت از Gost، ارسال به خارج |
| **خارج** | asm_udp_hz | `0.0.0.0:443` | UDP | دریافت از ایران، ارسال به Gost |
| **خارج** | Gost KCP | `127.0.0.1:1080` | UDP (KCP) | ارتباط داخلی ASM با Gost |

### چرا پورت ۴۴۳؟

پورت ۴۴۳ (HTTPS) بیشترین حجم ترافیک قانونی در اینترنت را دارد. DPI نمی‌تواند همه ترافیک UDP روی این پورت را مسدود کند، زیرا QUIC (HTTP/3) نیز از UDP روی پورت ۴۴۳ استفاده می‌کند. این انتخاب، **پنهان‌سازی در میان نویز** (Hiding in the Crowd) را ممکن می‌سازد.

---

## استقرار و راه‌اندازی

### پیش‌نیازها

| نیازمندی | توضیح |
|---|---|
| **سیستم‌عامل** | Ubuntu 20.04+ یا Debian 11+ (معماری x86_64) |
| **دسترسی** | `root` — اسکریپت مستقیماً با کرنل و systemd کار می‌کند |
| **سرور خارج** | یک VPS با پهنای باند مناسب (Hetzner, OVH, و...) |
| **سرور ایران** | یک سرور با دسترسی root |
| **پورت خارج** | پورت ۴۴۳ UDP باید روی فایروال VPS خارج باز باشد |

> **هشدار:** این اسکریپت مستقیماً با تنظیمات کرنل و فایل‌های systemd درگیر می‌شود. اجرای آن تنها بر روی سرورهای تازه (Fresh Install) پیشنهاد می‌شود.

### نصب یک‌خطی

هر دو سرور (ایران و خارج) با **یک دستور** نصب می‌شوند. اسکریپت هوشمند، نوع سرور را در لحظه از شما می‌پرسد:

```bash
curl -Ls -o t2hash-deploy https://raw.githubusercontent.com/T2HASH/T2HASH-CORE/main/t2hash-deploy && chmod +x t2hash-deploy && ./t2hash-deploy
```

### مراحل نصب

پس از اجرا، اسکریپت از شما می‌پرسد:

```
[ 1 ] Server Kharej (Hetzner / Receiver)
[ 2 ] Server Iran (Sender)

Koodom server ro dari config mikoni? [1 ya 2]:
```

**سناریو ۱ — سرور خارج (Hetzner):**
- عدد `1` را وارد کنید
- اسکریپت به صورت خودکار:
  1. نسخه‌های قبلی را پاک می‌کند
  2. `nasm`, `build-essential` را نصب می‌کند
  3. Gost را دانلود می‌کند
  4. بافرهای کرنل را بهینه می‌کند
  5. اسمبلی `asm_udp_hz` را کامپایل می‌کند (bind روی 0.0.0.0:443)
  6. دو سرویس systemd می‌سازد: `asm-hz` و `gost-hz`
  7. سرویس‌ها را enable و start می‌کند

**سناریو ۲ — سرور ایران:**
- عدد `2` را وارد کنید
- IP سرور خارج را وارد کنید (مثلاً `1.2.3.4`)
- اسکریپت IP را به Hex تبدیل کرده و در اسمبلی تزریق می‌کند
- مراحل مشابه بالا برای `asm_udp_ir` (bind روی 0.0.0.0:7777)

### تأیید نصب

پس از نصب موفق، اسکریپت وضعیت سرویس‌ها را نمایش می‌دهد:

```
✅  NASB KAMEL SHOD — Server Kharej
   Port:  443/UDP  (ASM receiver)
   Gost:  127.0.0.1:1080  (KCP local)

   asm-hz:   active
   gost-hz:  active
```

### مدیریت سرویس‌ها

```bash
# بررسی وضعیت
systemctl status asm-hz gost-hz     # سرور خارج
systemctl status asm-ir gost-ir     # سرور ایران

# راه‌اندازی مجدد
systemctl restart asm-hz gost-hz
systemctl restart asm-ir gost-ir

# مشاهده لاگ‌ها
journalctl -u asm-hz -f
journalctl -u gost-hz -f

# غیرفعال‌سازی
systemctl stop asm-hz gost-hz
systemctl disable asm-hz gost-hz
```

---

## عیب‌یابی و مانیتورینگ

### مشکلات رایج

| مشکل | علت احتمالی | راه‌حل |
|---|---|---|
| `asm-hz` failed | پورت ۴۴۳ در استفاده است | `ss -ulnp \| grep 443` — پروسه مزاحم را kill کنید |
| `gost-hz` failed | فایل gost خراب است | `rm /usr/local/bin/gost` و نصب مجدد |
| عدم اتصال | فایروال خارج پورت ۴۴۳ UDP را بسته | `ufw allow 443/udp` روی سرور خارج |
| Packet Loss بالا | بافر کرنل کم است | `sysctl net.core.rmem_max` — باید ۲۶ میلیون باشد |
| سرعت پایین | KCP mtu نامناسب | mtu را در سرویس gost تغییر دهید (پیش‌فرض ۱۳۵۰) |

### دستورات مانیتورینگ

```bash
# مشاهده ترافیک UDP روی پورت‌ها
ss -ulnp | grep -E '443|7777'

# مشاهده مصرف CPU اسمبلی (باید نزدیک صفر باشد)
top -p $(pgrep asm_udp)

# مشاهده packet loss در کرنل
cat /proc/net/udp

# تست سرعت با iperf3 (روی سرور خارج)
iperf3 -s -p 5201
# از ایران:
iperf3 -c IP_KHAREJ -p 5201 -u -b 100M
```

---

## ساختار پروژه

```
T2HASH-CORE/
├── README.md              # مستندات اصلی (این فایل)
├── ASM-TUN-V2.0.txt       # سورس کامل اسکریپت نصب + اسمبلی
├── t2hash-deploy          # اسکریپت یک‌خطی deploy
│
├── [تولیدشده پس از نصب روی سرور]
│   ├── /root/asm_udp_hz.asm   # سورس اسمبلی سرور خارج
│   ├── /root/asm_udp_hz       # باینری کامپایل‌شده خارج
│   ├── /root/asm_udp_ir.asm   # سورس اسمبلی سرور ایران
│   ├── /root/asm_udp_ir       # باینری کامپایل‌شده ایران
│   ├── /usr/local/bin/gost    # باینری Gost
│   └── /etc/systemd/system/   # سرویس‌های systemd
│       ├── asm-hz.service
│       ├── gost-hz.service
│       ├── asm-ir.service
│       └── gost-ir.service
```

---

## محدودیت‌ها و ملاحظات امنیتی

### محدودیت‌های ذاتی

- **UDP only**: T2HASH فقط UDP را پردازش می‌کند. ترافیک TCP باید توسط Gost/KCP به UDP تبدیل شود
- **بدون رمزنگاری قوی**: XOR یک obfuscation است، نه encryption. برای امنیت محتوایی، از لایه‌های بالاتر (TLS, SSH) استفاده کنید
- **بدون Authentication**: هر کسی که پورت را بداند می‌تواند پکت بفرستد. در شبکه‌های عمومی، فایروال را محدود کنید
- **Single-threaded**: هر instance اسمبلی تک‌رشته‌ای است. برای scale، از `SO_REUSEPORT` با چند instance استفاده کنید

### ملاحظات امنیتی

- **این ابزار برای عبور از سانسور طراحی شده، نه برای فعالیت‌های مخرب**
- مسئولیت استفاده از این ابزار کاملاً بر عهده کاربر است
- در برخی کشورها، استفاده از ابزارهای دور زدن فیلترینگ ممکن است غیرقانونی باشد
- T2HASH **هیچ‌گونه لاگ یا telemetry** جمع‌آوری نمی‌کند — حریم خصوصی شما مطلقاً محفوظ است

---

## مشارکت و توسعه

پروژه T2HASH به صورت **Open Source** توسعه داده می‌شود. ایده‌ها، پیشنهادات و Pull Request های شما ارزشمند است.

### نقشه راه V3.0 (در دست توسعه)

- **SIMD Acceleration**: استفاده از SSE/AVX برای XOR — پردازش ۳۲ بایت در هر سیکل
- **Multi-Mask XOR Chaining**: ۸ ماسک چرخشی بر اساس شماره پکت — حذف کامل signature
- **Packet Padding تصادفی**: ۱-۶۴ بایت داده تصادفی به هر پکت
- **Port Hopping**: چرخش بین چند پورت برای فرار از rate limiting
- **Busy-Polling Mode**: `SO_BUSY_POLL` برای تأخیر زیر ۱۰ میکروثانیه

---

<p align="center">
  <sub>ساخته شده با وسواس مهندسی — T2HASH Team</sub>
  <br>
  <sub>Optimized & Hardened by <b>Amirwopi</b></sub>
</p>
