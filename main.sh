#!/bin/bash
function check_if_status_active {
    status=$(systemctl is-active "$1")
    if [ "$status" == "active" ]; then
        echo "$1 is active"
    else
        echo "$1 is not active"
    fi
}

function check_ports_of_firewalld {
    ports=$(sudo firewall-cmd --list-ports)
    if [[ $ports == *"$1/tcp"* ]]; then
        echo "Port $1 is open in firewalld"
    else
        echo "Port $1 is not open in firewalld"
    fi
}

function check_if_database_exists {
result=$(sudo mysql -e "show databases;" | grep ecomdb)
    if [ "$result" == "ecomdb" ]; then
        echo "Database ecomdb exists"
    else
        echo "Database ecomdb does not exist"
    fi
}

function check_if_table_exists {
    result=$(sudo mysql -e "USE ecomdb; SHOW TABLES;" | grep products)
    if [ "$result" == "products" ]; then
        echo "Table products exists in ecomdb"
    else
        echo "Table products does not exist in ecomdb"
    fi
}

echo "Installing firewalld..."
sudo yum install firewalld -y
sudo systemctl start firewalld
sudo systemctl enable firewalld
check_if_status_active firewalld

echo "Installing mariadb..."
sudo yum install mariadb-server -y
sudo systemctl start mariadb
sudo systemctl enable mariadb
check_if_status_active mariadb

sudo firewall-cmd --permanent --zone=public --add-port=3306/tcp
sudo firewall-cmd --reload
check_ports_of_firewalld 3306

sudo mysql << EOF
CREATE DATABASE ecomdb;
CREATE USER 'ecomuser'@'localhost' IDENTIFIED BY 'ecompassword';
GRANT ALL PRIVILEGES ON *.* TO 'ecomuser'@'localhost';
FLUSH PRIVILEGES;
exit
EOF

check_if_database_exists

cat > db-load-script.sql <<-EOF
USE ecomdb;
CREATE TABLE products (id mediumint(8) unsigned NOT NULL auto_increment,Name varchar(255) default NULL,Price varchar(255) default NULL, ImageUrl varchar(255) default NULL,PRIMARY KEY (id)) AUTO_INCREMENT=1;

INSERT INTO products (Name,Price,ImageUrl) VALUES ("Laptop","100","c-1.png"),("Drone","200","c-2.png"),("VR","300","c-3.png"),("Tablet","50","c-5.png"),("Watch","90","c-6.png"),("Phone Covers","20","c-7.png"),("Phone","80","c-8.png"),("Laptop","150","c-4.png");

EOF

sudo mysql -u root < db-load-script.sql


check_if_table_exists

sudo yum install -y httpd php php-mysqlnd
sudo firewall-cmd --permanent --zone=public --add-port=80/tcp
sudo firewall-cmd --reload

check_ports_of_firewalld 80

sudo sed -i 's/index.html/index.php/g' /etc/httpd/conf/httpd.conf

sudo systemctl start httpd
sudo systemctl enable httpd

check_if_status_active httpd

sudo yum install -y git
sudo git clone https://github.com/kodekloudhub/learning-app-ecommerce.git /var/www/html/

sudo tee /var/www/html/.env <<-EOF > /dev/null
DB_HOST=localhost
DB_USER=ecomuser
DB_PASSWORD=ecompassword
DB_NAME=ecomdb
EOF

sudo awk '
/\$dbHost = getenv\('"'"'DB_HOST'"'"'\);/ {
    print "function loadEnv($path)"
    print "{"
    print "    if (!file_exists($path)) {"
    print "        return false;"
    print "    }"
    print "    $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);"
    print "    foreach ($lines as $line) {"
    print "        if (strpos(trim($line), '"'"'#'"'"') === 0) {"
    print "            continue;"
    print "        }"
    print "        list($name, $value) = explode('"'"'='"'"', $line, 2);"
    print "        $name = trim($name);"
    print "        $value = trim($value);"
    print "        putenv(sprintf('"'"'%s=%s'"'"', $name, $value));"
    print "    }"
    print "    return true;"
    print "}"
    print "loadEnv(__DIR__ . '"'"'/.env'"'"');"
    print "$dbHost = getenv('"'"'DB_HOST'"'"');"
    print "$dbUser = getenv('"'"'DB_USER'"'"');"
    print "$dbPassword = getenv('"'"'DB_PASSWORD'"'"');"
    print "$dbName = getenv('"'"'DB_NAME'"'"');"
    
    for(i=0; i<3; i++) getline
    next
}
{ print }
' /var/www/html/index.php > /tmp/index_new.php && sudo mv /tmp/index_new.php /var/www/html/index.php