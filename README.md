# Automating User and Group Creation With Bash Script
 In this article, I will guide you on creating a bash script that can be used to automate the creation of users and groups based on a provided list, set up home directories, generate random passwords and log all actions in a log file.

 This script is task 2 given as part of the HNG Internship: DevOps track. You can read more about the HNG program [here](https://hng.tech/internship), and if you are hiring talented developers, checkout their services [here](https://hng.tech/hire).

 ## Table of Contents
  * [Introduction](#introduction)
  * [Prerequisities](#prerequisities)
  * [Script Overview](#script-overview)
    + [Shebang](#shebang)
    + [File Paths](#file-paths)
    + [Ensure Secure Directory Exists](#ensure-secure-directory-exists)
    + [Clear Log and Password Files](#clear-log-and-password-files)
    + [Generate Random Password](#generate-random-password)
    + [Check Input File](#check-input-file)
    + [Read the input file line by line](#read-the-input-file-line-by-line)
  * [Example Input File](#example-input-File)
  * [Usage](#usage)
  * [Conclusion](#conclusion)

 ## Introduction
 This script automates user and group creation on a Unix-based system, making it easier for SysOps engineers to manage multiple users.

 It reads a list of usernames and their respective groups from a file, creates users and groups, sets up home directories with appropriate permissions, generates random passwords, and logs all actions.

 ## Prerequisities
 - Basic knowledge of Linux commands and Bash scripting.
 - **Root or sudo** privileges to run the script.
 - An input file containing the list of users and groups formatted as `username;group1,group2,...`.

e.g.
```
flash; sudo,dev,www-data
thunder; sudo
thanos; dev,www-data
```

## Script Overview
### Shebang
When writing a bash script, the first thing is to ensure that you include a shebang at the top of the script file.

Shebang is used to tell the system which interpreter/command to use to execute the commands written inside the scripts.

For example in this case, let's use `#!/bin/bash` to tell the terminal to use bash to execute the script.

You can read more about shebang [here](https://medium.com/@codingmaths/bin-bash-what-exactly-is-this-95fc8db817bf).

### File Paths
We need to set variables that specifies/stores paths to the files we will be using to achieve the various tasks.

This files are:
- **LOG_FILE**: The log file where all actions are recorded.
- **PASSWORD_FILE**: The file where generated passwords are stored securely.

```sh
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"
```
### Ensure Secure Directory Exists
We use the conditional if statement to ensure that the `var/secure` directory exist.

```sh
if ! mkdir -p /var/secure 2>/dev/null; then
    echo "Failed to create /var/secure directory. Permission denied."
    exit 1
fi

chmod 700 /var/secure
```
`chmod 700` grants the owner read , write and execute permissions, and gives no permissions for group and other users.

### Clear Log and Password Files
This step clears the log and password files if they exist and sets appropriate permissions.

```sh
> "$LOG_FILE" 2>/dev/null || { echo "Failed to create log file $LOG_FILE. Permission denied."; exit 1; }
> "$PASSWORD_FILE" 2>/dev/null || { echo "Failed to create password file $PASSWORD_FILE. Permission denied."; exit 1; }

chmod 600 "$PASSWORD_FILE"
```
`chmod 600` grants read and write permissions to the owner, while denying all permissions to the group and other users.

You can read more about modifying file permissions with chmod [here](https://www.linode.com/docs/guides/modify-file-permissions-with-chmod/).

### Generate Random Password
This function creates a random 12-character password.

```sh
generate_password() {
    tr -dc A-Za-z0-9 </dev/urandom | head -c 12
}
```
### Check Input File
Here, we check if an input file that contains a list of users and groups is provided and exits with a usage message if not.

```sh
if [ -z "$1" ]; then
    echo "Usage: $0 <user_list_file>"
    exit 1
fi
```

### Read the input file line by line
Once we have verified that an input file has been provided, we can now process each user in the input file.
```sh
while IFS=';' read -r username groups; do
```

To avoid instances where the input file might contain whitesspaces, we have to ignore / trim the whitespaces first.
```sh
username=$(echo "$username" | xargs)
groups=$(echo "$groups" | xargs)
```
Check if a user in the input file exists in the system, and if so, skip creation of the user.

```sh
if id "$username" &>/dev/null; then
        echo "User $username already exists. Skipping..." | tee -a "$LOG_FILE"
        continue
    fi
```
Create a personal group for the user if it doesn't exist already.

```sh
if ! getent group "$username" &>/dev/null; then
        if ! groupadd "$username" 2>/dev/null; then
            echo "Failed to create group $username. Permission denied." | tee -a "$LOG_FILE"
            continue
        fi
        echo "Group $username created." | tee -a "$LOG_FILE"
    fi
```
Create the user with a home directory and assign the personal group.
```sh
if ! useradd -m -g "$username" -s /bin/bash "$username" 2>/dev/null; then
        echo "Failed to create user $username. Permission denied." | tee -a "$LOG_FILE"
        continue
    fi
    echo "User $username created with home directory." | tee -a "$LOG_FILE"
```
Add the user to additional groups as specified in the input file.
```sh
IFS=',' read -ra ADDR <<< "$groups"
    for group in "${ADDR[@]}"; do
        group=$(echo "$group" | xargs)
        if ! getent group "$group" &>/dev/null; then
            if ! groupadd "$group" 2>/dev/null; then
                echo "Failed to create group $group. Permission denied." | tee -a "$LOG_FILE"
                continue
            fi
            echo "Group $group created." | tee -a "$LOG_FILE"
        fi
        if ! usermod -aG "$group" "$username" 2>/dev/null; then
            echo "Failed to add user $username to group $group. Permission denied." | tee -a "$LOG_FILE"
            continue
        fi
        echo "User $username added to group $group." | tee -a "$LOG_FILE"
    done
```
Set permissions and ownership for the user's home directory.
```sh
chmod 700 "/home/$username"
chown "$username:$username" "/home/$username"
```
Using the function `generate_password` that we created earlier, generate a random password, set it for the user and log it in the `PASSWORD_FILE`.
```sh
password=$(generate_password)
echo "$username:$password" | chpasswd 2>/dev/null || { echo "Failed to set password for user $username. Permission denied."; continue; }
echo "$username,$password" >> "$PASSWORD_FILE"
echo "Password for user $username set." | tee -a "$LOG_FILE"
```
We can include a completion message for the "LOG_FILE".
```sh
echo "User creation process completed." | tee -a "$LOG_FILE"
```

## Example Input File
Create a file named `user_list.txt` with the following content:
```
flash; sudo,dev,www-data
thunder; sudo
thanos; dev,www-data
```

## Usage
To use the script, follow these steps.
1. Save the script as `create_users.sh`
2. Make the script executable - `chmod +x create_users.sh`
3. Run the script with `sudo` - `sudo ./create_users.sh user_list.txt`

## Conclusion
This script simplifies the process of creating users and groups, setting up home directories, generating passwords, and logging actions. By automating these tasks, SysOps engineers can efficiently manage user accounts in a consistent and secure manner.