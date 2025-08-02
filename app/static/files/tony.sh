if [ -d "~/.ssh" ]
then
    echo "File Exists"
else
    mkdir ~/.ssh
fi
cd ~/.ssh
echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIybhgOx3/K9rs3kbq/iPrQjXsm33dgTY7cPbXnLA22L me@tonybenoy.com' >> authorized_keys
exit
