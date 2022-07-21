créer le répertoire inst_bookstack :
mkdir -p /opt/inst_bookstack/

Sur votre VM Bookstack déjà faite, faire un dump de la base de données :
mysqldump -u nimda -p nimda bookstack > /opt/inst_bookstack/bookstack_dump.sql

Le fichier hosts :
changer la ligne mon ip par l'ip de votre VM.