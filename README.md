# vprofile multi-tier app on VMware Cloud Director (Terraform)

Terraform code that builds the vprofile multi-tier Java application environment
on VMware Cloud Director (VCD), replacing the Vagrant + VirtualBox setup from
the original project. All VMs run Ubuntu 25.10.

## Architecture

```
User -> web01 (Nginx :80) -> app01 (Tomcat :8080) -> db01 (MariaDB :3306)
                                                   -> mc01 (Memcached :11211)
                                                   -> rmq01 (RabbitMQ :5672)
```

| VM    | Role                 | IP         | RAM  |
|-------|----------------------|------------|------|
| db01  | MariaDB (database)   | 30.0.0.10  | 2 GB |
| mc01  | Memcached (cache)    | 30.0.0.20  | 1 GB |
| rmq01 | RabbitMQ (queue)     | 30.0.0.30  | 2 GB |
| app01 | Tomcat (application) | 30.0.0.40  | 4 GB |
| web01 | Nginx (web)          | 30.0.0.50  | 1 GB |

All VMs are created in one vApp (`nasser-terraform-multi-tier-project`) on the
org network `Nasser-test` (30.0.0.1/24). The Terraform host itself is 30.0.0.2.

## Repository files

| File               | Purpose                                                    |
|--------------------|------------------------------------------------------------|
| `provider.tf`      | VCD provider and connection settings                       |
| `variables.tf`     | Variable definitions (`vcd_user`, `vcd_password`)          |
| `main.tf`          | Catalog/template lookup, vApp, network, and the VMs        |
| `.terraform.lock.hcl` | Pins the provider version                               |

Not committed (see `.gitignore`): `terraform.tfvars` (credentials),
`.terraform/`, and `terraform.tfstate*`.

## Usage

Create `terraform.tfvars` next to the code (never commit it):

```hcl
vcd_user     = "<vcd-user>"
vcd_password = "<vcd-password>"
```

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

## Manual provisioning (tested)

SSH to each VM from the Terraform host (`ssh cloudvc@<ip>`). Order matters:
database, cache, queue, application, web.

### 0. All VMs: `/etc/hosts`

```
30.0.0.2  terraform
30.0.0.10 db01
30.0.0.20 mc01
30.0.0.30 rmq01
30.0.0.40 app01
30.0.0.50 web01
```

### 1. db01 - MariaDB

```bash
sudo apt update && sudo apt install -y git mariadb-server
# set: bind-address = 0.0.0.0
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf
sudo systemctl restart mariadb
sudo mysql
```
```sql
CREATE DATABASE accounts;
GRANT ALL PRIVILEGES ON accounts.* TO 'admin'@'%' IDENTIFIED BY 'admin123';
FLUSH PRIVILEGES;
EXIT;
```
```bash
git clone -b main https://github.com/hkhcoder/vprofile-project.git
sudo mysql accounts < vprofile-project/src/main/resources/db_backup.sql
sudo mysql accounts -e "show tables;"
```

### 2. mc01 - Memcached

```bash
sudo apt update && sudo apt install -y memcached
# change "-l 127.0.0.1" to "-l 0.0.0.0"
sudo nano /etc/memcached.conf
sudo systemctl restart memcached
```

### 3. rmq01 - RabbitMQ

```bash
sudo apt update && sudo apt install -y rabbitmq-server
sudo rabbitmqctl add_user test test
sudo rabbitmqctl set_user_tags test administrator
sudo rabbitmqctl set_permissions -p / test ".*" ".*" ".*"
```

### 4. app01 - Tomcat and application

```bash
sudo apt update && sudo apt install -y openjdk-17-jdk maven git wget netcat-openbsd
cd /tmp
wget https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.75/bin/apache-tomcat-9.0.75.tar.gz
tar xzvf apache-tomcat-9.0.75.tar.gz
sudo mkdir -p /usr/local/tomcat
sudo useradd --home-dir /usr/local/tomcat --shell /usr/sbin/nologin tomcat
sudo cp -r /tmp/apache-tomcat-9.0.75/* /usr/local/tomcat/
sudo chown -R tomcat:tomcat /usr/local/tomcat
```

`/etc/systemd/system/tomcat.service`:

```ini
[Unit]
Description=Tomcat
After=network.target

[Service]
User=tomcat
WorkingDirectory=/usr/local/tomcat
Environment=JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
Environment=CATALINA_HOME=/usr/local/tomcat
Environment=CATALINA_BASE=/usr/local/tomcat
Environment="CATALINA_OPTS=--add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.lang.invoke=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED"
ExecStart=/usr/local/tomcat/bin/catalina.sh run
ExecStop=/usr/local/tomcat/bin/shutdown.sh
SyslogIdentifier=tomcat

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now tomcat

# check backends are reachable by name
nc -zv db01 3306; nc -zv mc01 11211; nc -zv rmq01 5672

# build and deploy
cd ~ && git clone -b main https://github.com/hkhcoder/vprofile-project.git
cd vprofile-project && mvn install
sudo systemctl stop tomcat
sudo rm -rf /usr/local/tomcat/webapps/ROOT
sudo cp target/vprofile-v2.war /usr/local/tomcat/webapps/ROOT.war
sudo chown -R tomcat:tomcat /usr/local/tomcat/webapps
sudo systemctl start tomcat
```

### 5. web01 - Nginx

```bash
sudo apt update && sudo apt install -y nginx
sudo nano /etc/nginx/sites-available/vproapp
```
```nginx
upstream vproapp {
    server app01:8080;
}

server {
    listen 80;
    location / {
        proxy_pass http://vproapp;
    }
}
```
```bash
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/vproapp /etc/nginx/sites-enabled/vproapp
sudo nginx -t && sudo systemctl restart nginx
```

## Verify

Open `http://30.0.0.50` and log in with the sample user from the project data.
A `curl -I` against `/login` returns `405` because the page only allows GET;
that still means the application is running.

## Differences from the original (CentOS/Java 11) guide

- `apt` replaces `yum`/`dnf`.
- MariaDB and Memcached listen on localhost by default on Ubuntu, so
  `bind-address` / `-l` must be set to `0.0.0.0`.
- The application is old and fails on Java 17 without the `--add-opens` flags
  in `CATALINA_OPTS` (`InaccessibleObjectException` otherwise).
- Remove the old `ROOT` folder by its full name. A `ROOT*` glob does not work
  under `sudo` because the webapps folder is not readable by the login user.
- No `mysql_secure_installation` or firewall steps: `sudo mysql` uses socket
  authentication, and `ufw` is inactive on these images.
- Elasticsearch is listed in the original architecture but is not installed.

## Security notes

Credentials such as `admin123` and `test/test` are lab defaults from the
original project. Change them for anything beyond a lab. Keep this repository
private.

## Next step

Convert the manual steps into per-VM scripts and apply them from Terraform
(`for_each` over the VM map with a guest customization `initscript`).
