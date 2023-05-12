if [ - ~/.ssh] 
then
    echo "File Exists"
else
    mkdir ~/.ssh
fi
cd ~/.ssh
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDDug2C5UyeKLSmqxV6pBlYQeITHNeKK0BAE+NeZo6plZwCg8iwxKaj6Kf8lmx7Qlm8G+/iR3Ophrc+U1yUkfTaqeFmFe9bN2ZQw44kQWVD8YyyR1R6MORbHCxRBaTgGjR3mKqUxIkdg4oWcjrwvoEqYthwijbnoxj+qcxgTTTXizEiHIBAYhtNiWeJszpYknk/mJvZrhWLrMGhwcP62EpHltZJ3F/lsc0mOlU2MoVFJNM0WgWn9QcF0EGdmv4/rtOi0232dK8ik1OXP5OoiovQnDuHyGE1sYxdREjU2bokn8uSHdHkAqQZvLwQiWOk8URdWLYmard+M9Q7Al5e4W+h' >> authorized_keys
exit
