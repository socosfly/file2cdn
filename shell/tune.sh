#!/bin/bash

for pkg in ntpdate htpdate; do
    if ! command -v $pkg &> /dev/null; then
        apt install $pkg -y
    fi
done

timedatectl set-timezone Asia/Shanghai

ntpdate time1.google.com || htpdate -s www.baidu.com
hwclock -w

entropy=$(cat /proc/sys/kernel/random/entropy_avail)
if [ $entropy -lt "1000" ] && ! systemctl is-active --quiet haveged; then
    apt install haveged -y
    systemctl enable haveged
    systemctl restart haveged
fi

echo "1048576" > /proc/sys/fs/file-max
ulimit -n 1048576

chattr -i /etc/sysctl.conf
cat > /etc/sysctl.conf << EOF
# Memory usage
# https://blog.cloudflare.com/the-story-of-one-latency-spike/
# https://cloud.google.com/architecture/tcp-optimization-for-network-performance-in-gcp-and-hybrid/
# https://zhensheng.im/2021/01/31/linux-wmem-and-rmem-adjustments.meow
# https://github.com/redhat-performance/tuned/blob/master/profiles/network-throughput/tuned.conf
# ReceiveBuffer: X - (X / (2 ^ tcp_adv_win_scale)) = RTT * Bandwidth / 8
# SendBuffer: RTT * Bandwidth / 8 * 0.7
net.core.netdev_max_backlog = 262144
net.ipv4.tcp_max_syn_backlog = 8192
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 16384 131072 67108864
net.ipv4.tcp_wmem = 4096 16384 33554432
net.ipv4.udp_rmem_min = 131072
net.ipv4.udp_wmem_min = 131072

# Layer 2
# No Proxy ARP, obviously
net.ipv4.conf.default.proxy_arp = 0
net.ipv4.conf.all.proxy_arp = 0
# Do not reply ARP requests if the target IP address is not configured on the incoming interface
net.ipv4.conf.default.arp_ignore = 1
net.ipv4.conf.all.arp_ignore = 1
# When sending ARP requests, use the best IP address configured on the outgoing interface
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2
# Enable gratuitous arp requests
net.ipv4.conf.default.arp_notify = 1
net.ipv4.conf.all.arp_notify = 1

# IPv4 routing
net.ipv4.ip_forward = 1
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.send_redirects = 0
# Enable when there are 1-2K hosts
net.ipv4.neigh.default.gc_thresh1 = 2048
net.ipv4.neigh.default.gc_thresh2 = 4096
net.ipv4.neigh.default.gc_thresh3 = 8192

# IPv6 routing
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.default.forwarding = 1
net.ipv6.conf.all.forwarding = 1
# Enable when there are 1-2K hosts
net.ipv6.neigh.default.gc_thresh1 = 4096
net.ipv6.neigh.default.gc_thresh2 = 8192
net.ipv6.neigh.default.gc_thresh3 = 16384

# PMTUD
# https://blog.cloudflare.com/path-mtu-discovery-in-practice/
net.ipv4.ip_no_pmtu_disc = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_base_mss = 1024

# MPLS & L3VPN support
# https://web.archive.org/web/20210301222346/https://cumulusnetworks.com/blog/vrf-for-linux/
# net.mpls.ip_ttl_propagate = 1
# net.mpls.default_ttl = 255
# net.mpls.platform_labels = 1048575
net.ipv4.tcp_l3mdev_accept = 0
net.ipv4.udp_l3mdev_accept = 0
net.ipv4.raw_l3mdev_accept = 0
# net.mpls.conf.lo.input = 1

# ICMP
net.ipv4.icmp_errors_use_inbound_ifaddr = 1
net.ipv4.icmp_ratelimit = 0
net.ipv6.icmp.ratelimit = 0

# TCP connection accepting
# https://serverfault.com/questions/518862/will-increasing-net-core-somaxconn-make-a-difference
net.core.somaxconn = 8192
net.ipv4.tcp_abort_on_overflow = 0

# TCP connection recycling
# https://dropbox.tech/infrastructure/optimizing-web-servers-for-high-throughput-and-low-latency
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_max_tw_buckets = 4096

# TCP congestion control
# https://blog.cloudflare.com/http-2-prioritization-with-nginx/
net.core.default_qdisc = fq_codel
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_window_scaling = 1

# TCP keepalive
net.ipv4.tcp_keepalive_time = 120
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 3

# TCP auxiliary
# https://dropbox.tech/infrastructure/optimizing-web-servers-for-high-throughput-and-low-latency
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_adv_win_scale = 1

# ECN
net.ipv4.tcp_ecn = 0
net.ipv4.tcp_ecn_fallback = 1

# ECMP hashing
# https://web.archive.org/web/20210204031636/https://cumulusnetworks.com/blog/celebrating-ecmp-part-two/
net.ipv4.fib_multipath_hash_policy = 1
net.ipv4.fib_multipath_use_neigh = 1

# GRE keepalive
# https://blog.artech.se/2016/01/10/4/
net.ipv4.conf.default.accept_local = 1
net.ipv4.conf.all.accept_local = 1

# IGMP
# https://phabricator.vyos.net/T863
net.ipv4.igmp_max_memberships = 512

# IPv6 route table size bug fix
# https://web.archive.org/web/20200516030405/https://lists.nat.moe/pipermail/transit-service/2020-May/000000.html
net.ipv6.route.max_size = 2147483647

# Prefer different parity for ip_local_port_range start and end value
net.ipv4.ip_local_port_range = 32768 60999
net.ipv4.ip_local_reserved_ports = 8443,46101-46119
# 👆 建议自行修改需要占用或使用的端口

# Maximum number of open files
fs.file-max = 1048576

# Avoid the use of swap spaces where possible
vm.swappiness = 1

# Disable ICMP
net.ipv4.icmp_echo_ignore_all = 1
net.ipv6.icmp_echo_ignore_all = 1
EOF

sysctl -p

cat > /etc/security/limits.conf << EOF
root     hard   nofile    1048576
root     soft   nproc     1048576
root     hard   nproc     1048576
root     soft   core      1048576
root     hard   core      1048576
root     hard   memlock   unlimited
root     soft   memlock   unlimited

*     soft   nofile    1048576
*     hard   nofile    1048576
*     soft   nproc     1048576
*     hard   nproc     1048576
*     soft   core      1048576
*     hard   core      1048576
*     hard   memlock   unlimited
*     soft   memlock   unlimited
EOF
