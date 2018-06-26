#!/bin/sh -x

pip uninstall ansible -y
find /var/log -type f | while read f; do echo -n '' > $f; done
find / -name 'authorized_keys' | while read key; do rm -f $key; done
shred -u /etc/ssh/*_key /etc/ssh/*_key.pub
rm -rf /tmp/* /tmp/.*
unset HISTFILE
find /root/.*history /home/*/.*history | while read h; do rm -f $h; done
