#!/bin/sh
#Author:https://github.com/emptysuns
echo "\033[35m******************************************************************\033[0m"
echo " ██      ██                    ██                  ██          
░██     ░██  ██   ██          ░██                 ░░           
░██     ░██ ░░██ ██   ██████ ██████  █████  ██████ ██  ██████  
░██████████  ░░███   ██░░░░ ░░░██░  ██░░░██░░██░░█░██ ░░░░░░██ 
░██░░░░░░██   ░██   ░░█████   ░██  ░███████ ░██ ░ ░██  ███████ 
░██     ░██   ██     ░░░░░██  ░██  ░██░░░░  ░██   ░██ ██░░░░██ 
░██     ░██  ██      ██████   ░░██ ░░██████░███   ░██░░████████
░░      ░░  ░░      ░░░░░░     ░░   ░░░░░░ ░░░    ░░  ░░░░░░░░ "
echo "\033[32mVersion:\033[0m 0.1"
echo "\033[32mGithub:\033[0m https://github.com/emptysuns/HiHysteria"
echo "\033[35m******************************************************************\033[0m"
echo "\033[41;37mReady to install!\033[0m\n\n"
echo  "\033[42;37mDowload:hysteria主程序... \033[0m"
wget -O /etc/hysteria/hysteria https://github.com/HyNetwork/hysteria/releases/download/v0.8.5/hysteria-linux-amd64
chmod 755 /etc/hysteria/hysteria
wget -O /etc/hysteria/hysteria/chnroutes.acl https://raw.githubusercontent.com/emptysuns/HiHysteria/main/acl/chnroutes.acl
echo "\033[32m下载完成！\033[0m"
echo  "\033[42;37m开始配置: \033[0m"
echo "\033[32m请输入您的域名(必须是存在的域名，并且解析到此ip):\033[0m"
read  domain
echo "\033[32m请输入你想要开启的端口（此端口是server的开启端口10000-65535）：\033[0m"
read  port
echo "期望速度，请如实填写，这是客户端的峰值速度，服务端默认不受限。\033[31m期望过低或者过高会影响转发速度！\033[0m"
echo "\033[32m请输入客户端期望的下行速度:\033[0m"
read  download
echo "\033[32m请输入客户端期望的上行速度:\033[0m" 
read  upload
echo "\033[32m请输入混淆口令（相当于连接密钥）:\033[0m"
read  obfs
echo "\033[32m配置录入完成！\033[0m"
echo  "\033[42;37m执行配置...\033[0m"
cat <<EOF > /etc/hysteria/config.json
{
  "listen": ":$port",
  "acme": {
    "domains": [
	"$domain"
    ],
    "email": "pekora@gmail.com"
  },
  "disable_udp": false,
  "obfs": "$obfs",
  "auth": {
    "mode": "password",
    "config": {
      "password": "pekopeko"
    }
  },
  "acl": "/etc/hysteria/hysteria/chnroutes.acl",
  "recv_window_conn": 15728640,
  "recv_window_client": 67108864,
  "max_conn_client": 4096,
  "disable_mtu_discovery": false
}
EOF

cat <<EOF > config.json
{
"server": "$domain:$port",
"up_mbps": $upload,
"down_mbps": $download,
"http": {
"listen": "127.0.0.1:8888",
"timeout" : 300,
"disable_udp": false
},
"acl": "chnroutes.acl",
"obfs": "$obfs",
"auth_str": "pekopeko",
"server_name": "$domain",
"insecure": false,
"recv_window_conn": 15728640,
"recv_window": 67108864,
"disable_mtu_discovery": false
}
EOF

cat <<EOF >/etc/systemd/system/hysteria.service
[Unit]
Description=hysteria:Hello World!
After=network.target

[Service]
ExecStart=/etc/hysteria/hysteria --log-level warn -c /etc/hysteria/config.json server
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF

chmod 644 /etc/systemd/system/hysteria.service
systemctl daemon-reload
systemctl enable hysteria
systemctl start hysteria
echo "Tips:客户端默认只开启http代理!http://127.0.0.1:8888\n\n"
echo  "\033[42;37m所有安装已经完成，配置文件已经在本目录生成！\033[0m\n\n"
cat ./config.json
