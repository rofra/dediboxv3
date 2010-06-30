#!/bin/sh
# Rodolphe Franceschi le 12/11/2009
# Script de creation d'un serveur de type OpenvZ
#
# Attention, on suppose que:
#  - Que le parent a une interface de type "vlan" ou autre pour dialoguer avec les enfants qui seront sur le range 10.10.16.1/16
#  - Le DNS se trouve sur le parent sur l'IP

# parametres a adapter en fonction du serveur
MODELE=/home/backups/20071012_installationvserver//vservers/default.tgz
STORE_DIR=/home/vservers
PARENT_IP="10.10.16.1"
PARENT_NAME="exvotoparent"




function usage {
   echo
   echo "Creation d'un serveur virtuel d'apres le nom et l'IP"
   echo "Usage :  $0 <NUMERO> <NOM>"
   echo
   vzlist
   echo
}

if [ $# -ne 2 ] ; then
   usage
   exit 1
fi

SNAME=$2
IP=$1

if [ -d $STORE_DIR/$2 ] ; then
  echo
  echo "ATTENTION, Il y a deja un vserver dans le repertoire $STORE_DIR/$2 , arret de l'installation"
  usage
  exit 1
fi

if [ ! -x /usr/bin/mkpasswd ]
then
   echo "Il faut installer le paquet whois pour avoir la commande mkpasswd"
   echo "Lancer la commande 'aptitude install whois'"
fi

if [ ! -e $STORE_DIR ]; then
   echo "Le repertoire de stockage $STORE_DIR n'existe pas."
   exit 1
fi

if [ ! -e $MODELE ]; then
   echo "Le modele $MODELE n'existe pas."
   exit 1
fi

echo
echo "Creation du serveur virtuel"
echo "nom:       $SNAME"
echo "ip:        $IP"
echo "modele:    $MODELE"
echo "parent:    $PARENT_NAME"
echo "IP parent: $PARENT_IP"
echo
echo "Note: ce script peut etre lance plusieurs fois avec les memes parametres."
echo -n "On le fait pour de bon ? (y/n) "
read RESPONSE
case $RESPONSE in
       Y|y|yes) ;;
       *)  echo "Abandon de la procedure."; exit 0;;
esac

# On forge un nom de machine avec le nom de domaine exvoto par defaut
SNAME_WITHDOMAIN=${SNAME}.exvoto.org

echo "Nom de machine forge : $SNAME_WITHDOMAIN"
echo

echo "Decompression de l'archive"
mkdir $STORE_DIR/$SNAME
tar -zxvf $MODELE -C /$STORE_DIR/$SNAME/

echo "Creation des liens symboliques"
ln -s $STORE_DIR/$SNAME/ /var/lib/vz/private/$IP

# Modification du GECOS
sed "s/root-[^:]*/root-$SNAME/" /$STORE_DIR/$SNAME/etc/passwd > /tmp/mk_server_$$ \
   && mv /tmp/mk_server_$$ /$STORE_DIR/$SNAME/etc/passwd

# Generation du password de l'enfant et remplacement dans le fichier /etc/shadow
NEWPASSWD=`mkpasswd --hash=MD5 $SNAME`
# on utilise un # car mkpasswd produit des / de temps en temps
sed "s#root:[^:]*#root:$NEWPASSWD#" /$STORE_DIR/$SNAME/etc/shadow > /tmp/mk_server_$$ \
   && mv /tmp/mk_server_$$ /$STORE_DIR/$SNAME/etc/shadow

echo $SNAME > /$STORE_DIR/$SNAME/etc/mailname

sed "s/^hostname=.*/hostname=$SNAME/" /$STORE_DIR/$SNAME/etc/ssmtp/ssmtp.conf > /tmp/mk_server_$$ \
   && mv /tmp/mk_server_$$ /$STORE_DIR/$SNAME/etc/ssmtp/ssmtp.conf
sed "s/^mailhub=.*/mailhub=$PARENT_NAME/" /$STORE_DIR/$SNAME/etc/ssmtp/ssmtp.conf > /tmp/mk_server_$$ \
   && mv /tmp/mk_server_$$ /$STORE_DIR/$SNAME/etc/ssmtp/ssmtp.conf


echo "On cree un fichier de configuration pour openvz pour le lancement et l'interface reseau"
cat /usr/local/bin/MODELEVZ.conf| sed -e "s/NUMEROVZ/${IP}/g" | sed -e "s/PARENTIP/${PARENT_IP}/g" | sed -e "s/NOMVZDOMAIN/${SNAME_WITHDOMAIN}/g" | sed -e "s/NOMVZ/${SNAME}/g" > /etc/vz/conf/${IP}.conf

echo "Creation du lien symbolique de lancement"
rm -f /var/lib/vz/private/${IP}
ln -s $STORE_DIR/$SNAME /var/lib/vz/private/${IP}

echo
echo "Demarrage de l'enfant"
vzctl start ${IP}

sleep 5s

echo
echo "Mise a jour de la distribution de l'enfant"
vzctl exec ${IP} gpg --keyserver wwwkeys.eu.pgp.net --recv-keys 9AA38DCD55BE302B
vzctl exec ${IP} apt-key add .gnupg/pubring.gpg
vzctl exec ${IP} aptitude update
vzctl exec ${IP} aptitude -y dist-upgrade
vzctl exec ${IP} aptitude -y clean --purge




echo
echo "Installation des packets de base"
vzctl exec ${IP} aptitude -y install vim zip unzip


# Configuration pour qu'Exim poste sur le papa directement (satellite)
echo "Installation d'EXIM4"
vzctl exec ${IP} aptitude -y install exim4
echo "dc_eximconfig_configtype='satellite'
dc_other_hostnames='${SNAME_WITHDOMAIN}'
dc_local_interfaces='127.0.0.1'
dc_readhost='${SNAME_WITHDOMAIN}'
dc_relay_domains=''
dc_minimaldns='false'
dc_relay_nets=''
dc_smarthost='10.10.16.1'
CFILEMODE='644'
dc_use_split_config='false'
dc_hide_mailname='true'
dc_mailname_in_oh='true'
dc_localdelivery='mail_spool'"> /tmp/update-exim4.conf.conf
alias cp='cp -f'
cp -f /tmp/update-exim4.conf.conf /$STORE_DIR/$SNAME/etc/exim4/update-exim4.conf.conf

vzctl exec ${IP} /etc/init.d/exim4 restart
echo

echo "Remplacement du nom de l'utilisateur root pour les mails"
sed -e "s/^root:x:0:0:root/root:x:0:0:Administrateur $SNAME/g" /$STORE_DIR/$SNAME/etc/passwd > /$STORE_DIR/$SNAME/etc/passwd_
alias mv='mv -f'
mv -f /$STORE_DIR/$SNAME/etc/passwd_ /$STORE_DIR/$SNAME/etc/passwd

echo "Test de l'envoi des mails"
vzctl exec ${IP} 'echo "BLA BLA" | mail -s "ggg" fedorage@gmail.com'

echo

echo
echo "Fin de l'installation"
