FROM alpine:latest

RUN set -eux; \
    apk update; \
    apk add --no-cache openssh bash zstd rsync htop wget curl sudo nano vim zip tmux python3 py-pip; \
    rm -rf /var/cache/apk/*;

# add user form `users.list`, and create user's home directory, give root access
COPY build/users.list /users.list
RUN set -eux; \
    # read users from `/users.list`
    while IFS= read -r line; do \
        echo "add user: $line"; \
        mkdir -p /home/$line; \
        adduser -D -s /bin/bash -h /home/$line $line; \
        # random password
        echo "$line:$(openssl rand -base64 32)" | chpasswd; \
        echo "$line ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$line; \
    done < /users.list;

# disable password login, only allow public key login
RUN set -eux; \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config; \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/g' /etc/ssh/sshd_config; \
    sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/g' /etc/ssh/sshd_config; \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config; \
    sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/g' /etc/ssh/sshd_config;

# add user's public key to authorized_keys from `build/users_pubkeys/{suer}`
COPY build/users_pubkeys /tmp/users_pubkeys
RUN set -eux; \
    while IFS= read -r line; do \
        mkdir -p /home/$line/.ssh; \
        cat /tmp/users_pubkeys/$line.pub > /home/$line/.ssh/authorized_keys; \
        chown -R $line:$line /home/$line/.ssh; \
        chmod 700 /home/$line/.ssh; \
        chmod 600 /home/$line/.ssh/authorized_keys; \
    done < /users.list;

# create /data directory
RUN set -eux; \
    mkdir -p /data

COPY build/motd /etc/motd

# start sshd
CMD set -eux; \
    # copy /host-keys/* to /etc/ssh/
    cp /host-keys/* /etc/ssh/ -f || true; \
    ssh-keygen -A; \
    # set permission for host keys
    chmod 600 /etc/ssh/ssh_host_*_key.pub; \
    chmod 400 /etc/ssh/ssh_host_*_key; \
    # copy back keys to /host-keys/
    cp /etc/ssh/ssh_host_*_key /host-keys/; \
    cp /etc/ssh/ssh_host_*_key.pub /host-keys/; \
    # lock down /host-keys/
    chmod 600 /host-keys -R; \
    chown root:root /host-keys -R; \
    # set permission for /data
    chown root:root /data; \
    chmod 775 /data; \
    # create /data/{user} directory for each user
    while IFS= read -r line; do \
        mkdir -p /data/$line; \
        chown $line:$line /data/$line; \
        chmod 705 /data/$line; \
        # link /data/{user} to /home/{user}/data
        if [ -d /home/$line/data ]; then rm -rf /home/$line/data; fi; \
        ln -s /data/$line /home/$line/data; \
    done < /users.list; \
    # start sshd
    exec /usr/sbin/sshd -D -e