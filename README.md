# SmartProxy 🚀

**ابزار سریع برای انتخاب بهترین پروکسی و تنظیم سیستم‌واید**

## نصب (۳۰ ثانیه)

```bash
git clone https://github.com/AminAzmoo/SmartProxy.git
cd SmartProxy
chmod +x smartproxy.sh
```

## استفاده

```bash
./smartproxy.sh              # منوی اصلی
./smartproxy.sh --find       # جسجو و انتخاب پروکسی
./smartproxy.sh --list       # نمایش تاریخچه
./smartproxy.sh --use        # استفاده از پروکسی فعلی
./smartproxy.sh --set <ip>   # تنظیم دستی
./smartproxy.sh --remove     # حذف پروکسی
```

## نیازمندی‌ها

- Linux
- Bash 4+
- Python 3.6+
- curl

## نحوه کار

1. **جسجو**: از ۱۰ منبع مختلف پروکسی را دریافت می‌کند
2. **تست**: هر پروکسی را ۳ بار تست می‌کند
3. **انتخاب**: بهترین پروکسی را انتخاب می‌کند
4. **تنظیم**: سیستم‌واید تنظیم می‌کند
5. **ذخیره**: برای استفاده‌های بعدی ذخیره می‌کند
