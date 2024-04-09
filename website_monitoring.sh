#!/bin/bash

# File paths
website_file="websites.txt"
recipient_file="recipient_list.txt"
email_notification_file1="/tmp/website_email_notification-up.txt"
email_notification_file2="/tmp/website_email_notification_check-up.txt"
url_alias_mapping_file="website_alias.txt"
counter_file="/tmp/website_counters-up.txt"
old_counter_file="/tmp/old_website_counters-up.txt"

# Email settings
#subject="SBM-Admin API Status Notification"
sender_name1="Websites Down Report"
sender_name2="Websites Up Report"
sender_email="indicsoftnoida@gmail.com"
subject1="Website Down"
subject2="Website Live Now"
mail_command="/usr/sbin/sendmail"


#INPUT FILES
HEADER=$(<header.html)
FOOTER=$(<footer.html)

# Function to send email notification
send_email() {
    echo "Subject: $subject1" > "$email_notification_file1"
    echo "To: $recipients" >> "$email_notification_file1"
    echo "Content-Type: text/html; charset=utf-8" >> "$email_notification_file1"
    echo -e "\n$1" >> "$email_notification_file1"
    $mail_command -F "$sender_name1" -f "$sender_email" -t < "$email_notification_file1"
}
send_email_check() {
    echo "Subject: $subject2" > "$email_notification_file2"
    echo "To: $recipients" >> "$email_notification_file2"
    echo "Content-Type: text/html; charset=utf-8" >> "$email_notification_file2"
    echo -e "\n$1" >> "$email_notification_file2"
    $mail_command -F "$sender_name2" -f "$sender_email" -t < "$email_notification_file2"
}

#ALIAS Name Function
declare -A url_alias_mapping
while IFS=' ' read -r url alias; do
    url_alias_mapping["$url"]=$alias
done < "$url_alias_mapping_file"

# Load counters or initialize if not exists
declare -A api_counters
if [ -e "$counter_file" ]; then
    source "$counter_file"
fi

declare -A OLD_COUNTERS
for url in "${!api_counters[@]}"; do
    OLD_COUNTERS["$url"]="${api_counters[$url]}"
done
declare -p OLD_COUNTERS > "$old_counter_file"

IFS= read -r recipients <<< "$(cat "$recipient_file")"

MIDDLE=""
at_least_one_not_working=false  # Flag to track whether at least one API is not working

#Main Function
while IFS= read -r url; do

    alias_name="${url_alias_mapping[$url]:-$url}"
    counter="${api_counters[$url]:-0}"
    # Hit the URL and get the HTTP status code
   # http_status=$(wget --server-response --no-check-certificate "$url" -O output_file 2>&1 | awk '/^  HTTP/{print $2}')

	max_retries=2
        while [ $max_retries -gt 0 ]; do   
            http_status=$(wget --server-response --no-check-certificate "$url" -O output_file 2>&1 | awk '/^  HTTP/{print $2}')
            # Check the exit code of wget
            if [ "$http_status" -eq 200 ]; then
		break  # Exit the loop if successful
            else
                max_retries=$((max_retries - 1))
		sleep 15
            fi
        done    
    
    
    recipient="${recipients[0]}"

    if [ "$http_status" -eq 200 ]; then
        echo "$alias_name is working (HTTP Status Code: $http_status). \n"
	api_counters["$url"]=0  # Reset counter if API is working
    else
        echo "$alias_name is not working (HTTP Status Code: $http_status). \n"
	api_counters["$url"]=$((counter + 1))  # Increment the counter if API is not working
	if [ "${api_counters[$url]}" -eq 1 ]; then
            at_least_one_not_working=true  # Set the flag to true if at least one API is not working for the first time
            MIDDLE+=$(cat <<EOF
            <div class="col-lg-12" style="display: flex;">
                <div class="col-md-6" style="width: 50%;">
                    <p style="border: 1px solid;margin: 0px;
                padding: 5px;
                text-align: center;">$alias_name</p>
                </div>
                <div class="col-md-6" style="width: 50%;">
                    <p style="border: 1px solid;
                padding: 5px;margin: 0px;
                text-align: center; color: red;">Website is DOWN !!!</p>
                </div>
            </div>
EOF
)
        fi
    fi
    echo
done < "$website_file"

# Store counters
declare -p api_counters > "$counter_file"

#Storing the HTML FORMAT and sending email only if at least one API is not working
if [ "$at_least_one_not_working" = true ]; then
    message="$HEADER$MIDDLE$FOOTER"
    send_email "$message"
fi

#Recheck
#declare -A OLD_COUNTERS
#for url in "${!api_counters[@]}"; do
#    OLD_COUNTERS["$url"]="${api_counters[$url]}"
#done
#declare -p OLD_COUNTERS > "$old_counter_file"

# Check for counter changes
for url in "${!api_counters[@]}"; do
    counter="${api_counters[$url]}"
#    echo "api_counters[$url]"
    if [ "$counter" -eq 0 ]; then
#	echo "in counter loop"
        if [ "${OLD_COUNTERS[$url]}" -gt 0 ]; then
            alias_name="${url_alias_mapping[$url]:-$url}"
#           echo "sending mail for $alias_name"
	    NEW_MIDDLE+=$(cat <<EOF
            <div class="col-lg-12" style="display: flex;">
                <div class="col-md-6" style="width: 50%;">
                    <p style="border: 1px solid;margin: 0px;
                padding: 5px;
                text-align: center;">$alias_name</p>
                </div>
                <div class="col-md-6" style="width: 50%;">
                    <p style="border: 1px solid;
                padding: 5px;margin: 0px;
                text-align: center; color: green;">Website is UP Now !!!</p>
                </div>
            </div>
EOF
)
	    new_message="$HEADER$NEW_MIDDLE$FOOTER"
	    send_email_check "$new_message"
        fi
    fi
#    echo "${api_counters[$url]} & ${OLD_COUNTERS[$url]}"
done

