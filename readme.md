# Centos 8 - SSH - GRPC

## This is a container with SSH enabled.

The following languages are available

- go 1.4.3
- gcc-9
- python 3

GRPC framework for all these languages

Run the docker from powershell:

```powershell
$SSH_KEY = Get-Content $env:USERPROFILE\.ssh\id_rsa.pub
docker run -it -d -p 2222:22 -e SSH_KEY=$SSH_KEY rodagurto/ssh-grpc-centos
```

To connect (Windows git-bash)

```bash
 ssh -p 2222 root@localhost
 ```