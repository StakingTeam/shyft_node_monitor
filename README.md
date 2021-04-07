# shyft_node_monitor

WHAT IS IT?

This is a tool to monitor your shyft node locally or remote. It also alerts you via telegram message in case of node down or block height stucked.

REQUIREMENTS

In order to make the tool work, you need the curl and jq packages

HOW TO USE

Clone this repository on your shyft node
Edit the config.ini file and put your telegram bot APITOKEN and CHATID. Finally, add 1 row for each node you'd like to monitor or leave the default value for the local one only
Launch the tool with the command ./node_monitor.sh (Using a tmux or screen session is recommended)

HOW IT WORKS

The tool will try to retrieve the block height from all the nodes listed in the config.ini and then check it again after a set time interval.
In the event that one or more nodes do not respond or the block height has not changed, it will send you an alert via telegram message in the chat set in the config.ini file.
The tool will also warn you when one or more previously reported problems will be solved.
