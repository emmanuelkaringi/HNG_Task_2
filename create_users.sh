#!/bin/bash

# File paths
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Ensure /var/secure directory exists
if ! mkdir -p /var/secure 2>/dev/null; then
    echo "Failed to create /var/secure directory. Permission denied."
    exit 1
fi
chmod 700 /var/secure

# Clear log and password files
> "$LOG_FILE" 2>/dev/null || { echo "Failed to create log file $LOG_FILE. Permission denied."; exit 1; }
> "$PASSWORD_FILE" 2>/dev/null || { echo "Failed to create password file $PASSWORD_FILE. Permission denied."; exit 1; }
chmod 600 "$PASSWORD_FILE"

# Function to generate a random password
generate_password() {
    tr -dc A-Za-z0-9 </dev/urandom | head -c 12
}

# Check if input file is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <user_list_file>"
    exit 1
fi

# Read the input file line by line
while IFS=';' read -r username groups; do
    # Trim whitespace
    username=$(echo "$username" | xargs)
    groups=$(echo "$groups" | xargs)

    if id "$username" &>/dev/null; then
        echo "User $username already exists. Skipping..." | tee -a "$LOG_FILE"
        continue
    fi

    # Create personal group with the same name as the user
    if ! getent group "$username" &>/dev/null; then
        if ! groupadd "$username" 2>/dev/null; then
            echo "Failed to create group $username. Permission denied." | tee -a "$LOG_FILE"
            continue
        fi
        echo "Group $username created." | tee -a "$LOG_FILE"
    fi

    # Create the user with the personal group
    if ! useradd -m -g "$username" -s /bin/bash "$username" 2>/dev/null; then
        echo "Failed to create user $username. Permission denied." | tee -a "$LOG_FILE"
        continue
    fi
    echo "User $username created with home directory." | tee -a "$LOG_FILE"

    # Add user to additional groups
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

    # Set up home directory permissions
    chmod 700 "/home/$username"
    chown "$username:$username" "/home/$username"

    # Generate a random password and set it for the user
    password=$(generate_password)
    echo "$username:$password" | chpasswd 2>/dev/null || { echo "Failed to set password for user $username. Permission denied."; continue; }

    # Log the password securely
    echo "$username,$password" >> "$PASSWORD_FILE"
    echo "Password for user $username set." | tee -a "$LOG_FILE"

done < "$1"

echo "User creation process completed." | tee -a "$LOG_FILE"