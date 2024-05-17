# share_container

`build/users.list` 中添加用户，每行一个，文件必须以 `\n` 结尾
`build/users_pubkeys` 中添加用户的公钥 `{user}.pub`

`docker build . -t share_container`

`docker compose up`

>[!WARNING]
> 仅 `~/data` 中的数据会被持久化