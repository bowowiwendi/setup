#!/bin/bash

# ┌──────────────────────────────────────────────┐
# │ Auto-Setup VPS Auto-Shutdown + Durasi Kustom │
# │ Simpan di GitHub (publik & aman)             │
# └──────────────────────────────────────────────┘

set -e

SECURE_DIR="/root/.secure_scripts"
SCRIPT_NAME=".auto_shutdown.sh"
LOG_NAME=".shutdown.log"

# Periksa apakah dijalankan sebagai root
if [[ $EUID -ne 0 ]]; then
   echo "❌ Skrip ini harus dijalankan sebagai root!"
   exit 1
fi

# Pasang dependensi
echo "🔧 Memeriksa dependensi..."
if ! command -v curl &> /dev/null; then
    (apt-get update &>/dev/null || yum update -y &>/dev/null)
    (apt-get install -y curl &>/dev/null || yum install -y curl &>/dev/null)
fi

if ! systemctl is-active --quiet atd 2>/dev/null; then
    (apt-get install -y at &>/dev/null || yum install -y at &>/dev/null)
    systemctl enable --now atd &>/dev/null
fi

mkdir -p "$SECURE_DIR"
chmod 700 "$SECURE_DIR"

# Input dari pengguna
# echo
# echo "🔑 Masukkan kredensial Telegram Bot Anda:"
# read -p "   Bot Token (contoh: 123456:ABC-DEF1234...): " BOT_TOKEN
# read -p "   Chat ID (contoh: 123456789): " CHATID

echo
read -p "   Durasi aktif VPS (dalam hari, contoh: 30): " DURATION_DAYS

# Validasi input
# if [[ -z "$BOT_TOKEN" ]] || [[ -z "$CHATID" ]]; then
#     echo "❌ Token atau Chat ID tidak boleh kosong!"
#     exit 1
# fi

# if ! [[ "$DURATION_DAYS" =~ ^[0-9]+$ ]] || [ "$DURATION_DAYS" -le 0 ]; then
#     echo "❌ Durasi harus berupa angka positif (misal: 7, 30, 90)!"
#     exit 1
# fi

# Ambil data sistem
MYIP=$(curl -s ipinfo.io/ip || echo "Tidak diketahui")
START_DATE=$(date '+%d-%m-%Y')
END_DATE=$(date -d "+$DURATION_DAYS days" '+%d-%m-%Y')

# Buat skrip auto-shutdown dinamis
cat > "$SECURE_DIR/$SCRIPT_NAME" <<EOF
#!/bin/bash

CHATID="5162695441"
KEY="7117869623:AAHBmgzOUsmHBjcm5TFir9JmaZ_X7ynMoF4"
URL="https://api.telegram.org/bot\$KEY/sendMessage"
DURATION="$DURATION_DAYS"

send_telegram() {
    curl -s --max-time 10 -d "chat_id=\$CHATID&text=\$1&parse_mode=html&disable_web_page_preview=1" "\$URL" >/dev/null 2>&1
}

MYIP=\$(curl -s ipinfo.io/ip || echo "Tidak diketahui")
SHUTDOWN_TIME=\$(date -d "+\${DURATION} days" '+%d-%m-%Y %H:%M:%S')

TEXT="
⚠️ <b>PERINGATAN SHUTDOWN VPS</b> ⚠️
VPS ini akan dimatikan secara otomatis dalam 1 jam.

📅 Jadwal Shutdown: <code>\$SHUTDOWN_TIME</code>
📍 IP VPS: <code>\$MYIP</code>

Jika ini tidak diinginkan, segera hubungi admin.
"

send_telegram "✅ Auto-shutdown aktif. VPS akan mati pada: <code>\$SHUTDOWN_TIME</code> (IP: \$MYIP)"

# Jadwalkan notifikasi 1 jam sebelum shutdown
echo "source $SECURE_DIR/$SCRIPT_NAME && send_telegram '\$TEXT'" | at "\$(date -d "+\$((DURATION - 1)) days 23 hours" '+%H:%M %Y-%m-%d')" 2>/dev/null

# Jadwalkan shutdown
echo "shutdown -h now" | at "\$(date -d "+\${DURATION} days" '+%H:%M %Y-%m-%d')" 2>/dev/null

echo "[\$(date)] Auto-shutdown diatur: \$SHUTDOWN_TIME (durasi: \${DURATION} hari)" >> "$SECURE_DIR/$LOG_NAME"
EOF

chmod 700 "$SECURE_DIR/$SCRIPT_NAME"
touch "$SECURE_DIR/$LOG_NAME"
chmod 600 "$SECURE_DIR/$LOG_NAME"

# === KIRIM NOTIFIKASI SETUP BERHASIL KE TELEGRAM ===
MESSAGE="
✅ <b>SETUP AUTO-SHUTDOWN BERHASIL!</b>

📆 Tanggal Mulai: <code>$START_DATE</code>
📅 Tanggal Berakhir: <code>$END_DATE</code>
⏳ Durasi Aktif: <code>$DURATION_DAYS hari</code>
📍 IP VPS: <code>$MYIP</code>

VPS akan mati otomatis setelah masa aktif habis.
Notifikasi peringatan akan dikirim 1 jam sebelum shutdown.
"

curl -s --max-time 10 \
  -d "chat_id=$CHATID&text=$MESSAGE&parse_mode=html&disable_web_page_preview=1" \
  "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" >/dev/null

# Jalankan skrip utama
"$SECURE_DIR/$SCRIPT_NAME" >/dev/null 2>&1

echo
echo "✅ Setup selesai!"
echo "   📆 Masa aktif: $START_DATE s/d $END_DATE ($DURATION_DAYS hari)"
echo "   📁 Skrip disimpan di: $SECURE_DIR/$SCRIPT_NAME"
echo "   📬 Notifikasi telah dikirim ke Telegram Anda."
