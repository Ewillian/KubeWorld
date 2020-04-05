# ⚔️ KubeWorld ⚔️

![image alt](https://d33wubrfki0l68.cloudfront.net/69e55f968a6f44613384615c6a78b881bfe28bd6/42cd3/_common-resources/images/flower.svg)

## 📄 Sommaire 📄

- Découpage de l'infrastructure
- Mise en place des namespaces
- KubeBD
- Wordpress
- RBAC
- Monitoring
- OIDC
- Registry + GUI Web

## ✂️ Découpage de l'infrastructure ✂️

Le découpage de l'infrastructure serait d'**un namespace par client**.
Ce choix est guidé par la volonté de garder les environements des clients indépendant des uns des autres.
Autrement dit, si un l'environnement du **client A** pose problème, il ne pourra impacter le bon fonctionnement de l'environnement du **client B**.

### Composants

A chaque namespace sera affecté un **quota**. Ce même namespace sera composé:
- d'un deployment
    - Wordpress
- d'un ingress
- d'un service
- d'un KubeDB
- d'un RBAC

### Organisation des fichiers et des dossiers

Comme chaque client à des besoins unique, les configurations des clients seront aussi séparées.

La structure correspondra à ce modèle:

![](https://i.imgur.com/uXYKNiY.png)


## 🏷 Mise en place des namespaces 🏷



```yaml
kind: Namespace
apiVersion: v1
metadata:
  name: test
  labels:
    name: test
```



## 🗃️ KubeBD 🗃️

### Description

KubeDB est un framework pour Kubectl permetant de simplifier la "containerisation" des base de données.

Elle permet par exemple de:

- Créer une base de données déclarative à l'aide de CRD.
- Effectuer des sauvegardes ponctuelles ou périodiques dans diverse "cloud stores", par exemple S3, GCS, etc.
- Restaurer à partir d'une sauvegarde ou cloner toute base de données.
- Intégration native avec Prometheus pour la surveillance via l'opérateur Prometheus de CoreOS.
- Appliquer un verrouillage de suppression pour éviter la suppression accidentelle de la base de données.
- Gardez une trace des bases de données supprimées, nettoyez les instantanés antérieurs avec une seule commande.
- Utiliser cli pour gérer les bases de données comme kubectl pour Kubernetes.
> CRD: https://kubernetes.io/docs/tasks/access-kubernetes-api/custom-resources/custom-resource-definitions/

### Installation

L'[installation](https://kubedb.com/) est plûtot simple.

```bash
$ curl -fsSL https://github.com/kubedb/installer/raw/v0.13.0-rc.0/deploy/kubedb.sh | bash
```

Après avoir fais la commande ci-dessus, on peut tester si KubeDB est installé avec un `kubedb`.
> Si la commande `kubedb` retourne une érreur. La commande `curl -fsSL https://raw.githubusercontent.com/kubedb/installer/89fab34cf2f5d9e0bcc3c2d5b0f0599f94ff0dca/deploy/kubedb.sh | bash` peut possiblement installer correctement kubedb. 
> 
> [**Post orginal**](https://github.com/kubedb/issues/issues/691)

### Utilisation

Dans notre cas, KubeDB va nous servir à créer le service mysql.
Nous allons aussi mettre en place un service PhpMyAdmin pour pouvoir monitorer la base de donnée.

#### La base de donnée

Pour créer cette base de donnée, il nous faut un fichier de config:

```yaml
mysql.yaml

apiVersion: kubedb.com/v1alpha1
kind: MySQL
metadata:
  name: picroma-mysql
  namespace: picroma-namespace
spec:
  databaseSecret:
    secretName: mysql-auth
    username: root
    password: password
  version: "8.0.14"
  doNotPause: true
  storage:
    storageClassName: "standard"
    accessModes:
    - ReadWriteOnce
    resources:
      requests:
        storage: 50Mi
```

Pour utiliser ce fichier de configuration avec KubeDB, on fait:

```bash
kubedb create -f ${fichier.yaml}
```

On vérifie:

```bash
$ kubedb get my
NAME            VERSION   STATUS    AGE
picroma-mysql   8.0.14    Running   3h29m
```

Nous avons notre base de donnée !
Passons donc à PhpMyAdmin.

#### PhpMyAdmin

Pour avoir un PhpMyAdmin entièrement fonctionnel, il nous faut un pod contenant l'app et un LoadBalancer

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: myadmin
  name: myadmin
  namespace: picroma-namespace
spec:
  selector:
    matchLabels:
      app: myadmin
  replicas: 1
  template:
    metadata:
      labels:
        app: myadmin
    spec:
      containers:
      - image: phpmyadmin/phpmyadmin
        imagePullPolicy: Always
        name: phpmyadmin
        ports:
        - containerPort: 80
          name: http
          protocol: TCP
        env:
          - name: PMA_ARBITRARY
            value: '1'

---

apiVersion: v1
kind: Service
metadata:
  labels:
    app: myadmin
  name: myadmin
  namespace: picroma-namespace
spec:
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: http
  selector:
    app: myadmin
  type: LoadBalancer
```

Il nous suffit de `kubectl create -f ${file.yaml}`.

On check !

```bash
ewillian@ewillian:~/Documents/KubeWorld/PicromaConfig/Deployment$ kubectl get pods
NAME                       READY   STATUS    RESTARTS   AGE
myadmin-58cd6c758c-6qz9c   1/1     Running   0          95m
picroma-mysql-0            1/1     Running   0          3h56
```

```bash
NAME                TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
myadmin             LoadBalancer   10.109.86.98   <pending>     80:30178/TCP   105m
picroma-mysql       ClusterIP      10.98.63.227   <none>        3306/TCP       3h57m
picroma-mysql-gvr   ClusterIP      None           <none>        3306/TCP       3h57m
```

Tout est en ordre.

Maintenant il nous faut nous connecter au service mysql via PhpMyAdmin.
Pour cela on récupère l'ip sur service PhpMyAdmin:

```bash
$ minikube service myadmin -n picroma-namespace --url
http://10.0.2.15:30178
```

On met cette ip dans notre navigateur.

![](https://i.imgur.com/bH0UHpb.png)

Ça fonctionne !

Maintenant il nous faut les identifiant.

Dans le fichier de config du service mysql, nous avons indiquer à mysql de garder des identifiant dans un `secret`.

```
spec:
  databaseSecret:
    secretName: mysql-auth
    username: root
    password: password
```

Pour vérifier / récupérer ces identifiant, il nous faut effectuer:

```bash
$   kubectl get secrets -n picroma-namespace picroma-mysql-auth -o jsonpath='{.data.\username}' | base64 -d

root

$   kubectl get secrets -n picroma-namespace picroma-mysql-auth -o jsonpath='{.data.\password}' | base64 -d

XUr3vbwW-2p-wJsa
```

Enfin, l'ip du pod mysql:

```bash
$ kubectl get pods picroma-mysql-0 -n picroma-namespace -o yaml | grep podIP
  
  podIP: 172.17.0.6
```

Plus qu'à se connecter !

![](https://i.imgur.com/EspEBGr.png)

## 🌐 Wordpress 🌐

Dans cette partie, nous allons refaire l'infrastructure précédente avec wordpress.

### Composants

Pour cela, nous vons besoin d'un namespace.

```yaml
kind: Namespace
apiVersion: v1
metadata:
  name: rockstar-namespace
  labels:
    name: rockstar-namespace
```

Du déploiement mysql kubedb légèrement modifié.

```yaml
apiVersion: kubedb.com/v1alpha1
kind: MySQL
metadata:
  name: wordpress-mysql
  labels:
    app: wordpress
  namespace: rockstar-namespace
spec:
  version: "5.7.25"
  storage:
    storageClassName: "standard"
    accessModes:
    - ReadWriteOnce
    resources:
      requests:
        storage: 1Gi
init:
  scriptSource:
    local:
      path: ./scripts/init-wordpress-database.sql
```

D'un Volume Persistent.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pv-claim
  labels:
    app: wordpress
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
```

D'un objet Secret pour l'utilisateur wordpress (chiffré en Base64).

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
type: Opaque
data:
  username: d29yZHByZXNz
  password: d29yZHByZXNz
```

Enfin, d'un script SQL pour initialiser l'utilisateur wordpress.

```sql
CREATE DATABASE IF NOT EXISTS wordpress;
CREATE USER 'wordpress'@'%' IDENTIFIED BY 'wordpress';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'%';
USE wordpress;
```

### Étape de mise en place

- (1) Création du Namespace.

```
kubectl apply -f namespace.yaml
```

**Resultat :**

- (2) Création du Secret.

```
kubectl apply -f wordpress-auth-mysql.yaml
```

**Resultat :**

- (3) Création Du volume persistent.

```
kubectl apply -f mysql-deployment.yaml
```

**Resultat :**

- (4) Application du déploiement KubeDB Mysql.

```
kubedb create -f mysql.yaml
```

**Resultat :**

- (5) Application du déploiement Wordpress

```
kubectl apply -f wordpress-deployment.yaml
```

**Resultat :**

- (6) Récupération URL et Connexion

```
sudo minikube service wordpress -n rockstar-namespace --url
```

**Resultat :**

## 🧔 RBAC (Role-Based Access Control) 🧔

Le contrôle d’accès basé sur les rôles (RBAC) est une méthode de régulation de l’accès aux ordinateurs et aux ressources réseau basée sur les rôles des utilisateurs individuels au sein d’une entreprise. Nous pouvons utiliser le contrôle d’accès basé sur les rôles sur toutes les ressources Kubernetes supportant les accès CRUD (Create, Read, Update, Delete). 

### Création d'utilisateur

Les utilisateurs normaux sont supposés être gérés par un service externe indépendant. Un administrateur distribuant des clés privées, un magasin d’utilisateurs comme Keystone ou des comptes Google, voire un fichier contenant une liste de noms d’utilisateur et de mots de passe. À cet égard, Kubernetes n’a pas d’objets qui représentent des comptes d’utilisateur normaux. Les utilisateurs normaux ne peuvent pas être ajoutés à un cluster via un appel d’API.

Dans notre cas, nous utiliserons les certificats clients X.509 avec OpenSSL pour leur simplicité. Il existe différentes étapes pour la création de ces utilisateurs.

- Création d’un utilisateur sur la machine principale puis se rendre dans sa home pour effectuer les étapes restantes.

```
adduser geraldderive

cd /home/geraldderive
```

**Resultat:**

```
ewillian@ewillian:/home$ sudo adduser geraldderive

Ajout de l utilisateur « geraldderive » ...
Ajout du nouveau groupe « geraldderive » (1002) ...
Ajout du nouvel utilisateur « geraldderive » (1002) avec le groupe « geraldderive » ...
Création du répertoire personnel « /home/geraldderive »...
Copie des fichiers depuis « /etc/skel »...
Entrez le nouveau mot de passe UNIX : 
Retapez le nouveau mot de passe UNIX : 
passwd : le mot de passe a été mis à jour avec succès
Modification des informations relatives à l utilisateur geraldderive
Entrez la nouvelle valeur ou « Entrée » pour conserver la valeur proposée
    Nom complet []: Gerald De Rive
    N° de bureau []: 
    Téléphone professionnel []: 
    Téléphone personnel []: 
    Autre []: 
Ces informations sont-elles correctes ? [O/n] o
```


- Création de sa private key :

```
openssl genrsa -out geraldderive.key 2048
```

- Création d’une demande de signature de certificat (CSR). CN est le nom de l’utilisateur et O est le groupe. Il est possible de définir des autorisations à l’échelle d’un groupe, ce qui peut simplifier la gestion si plusieurs utilisateurs partagent les mêmes autorisations.

```
# Without Group
openssl req -new \
-key geraldderive.key \
-out geraldderive.csr \
-subj "/CN=geraldderive"

# With a Group where $group is the group name
openssl req -new \
-key geraldderive.key \
-out geraldderive.csr \
-subj "/CN=geraldderive/O=$group"

#If the user has multiple groups
openssl req -new \
-key geraldderive.key \
-out geraldderive.csr \
-subj "/CN=geraldderive/O=$group1/O=$group2/O=$group3"
```

- Signer le CSR avec le CA de Kubernetes. Le certificat et la clé de Kubernetes sont locallisés dans /etc/kubernetes/pki. Les certificats générés ci-dessous seront valides pour 500 jours.

```
openssl x509 -req \
-in geraldderive.csr \
-CA /etc/kubernetes/pki/ca.crt \
-CAkey /etc/kubernetes/pki/ca.key \
-CAcreateserial \
-out geraldderive.crt -days 500
```

- Création d’un répertoire “.certs” où sera stocké les clé public et privées de l’utilisateur.

```
mkdir .certs && mv geraldderive.crt geraldderive.key .certs
```

- Création de l’utilisateur dans Kubernetes.

```
kubectl config set-credentials geraldderive \
--client-certificate=/home/geraldderive/.certs/geraldderive.crt \
--client-key=/home/geraldderive/.certs/geraldderive.key
```

- Création d’un contexte associé à l’utilisateur.

```
kubectl config set-context geraldderive-context \
--cluster=kubernetes --user=geraldderive
```

- Edition du fichier de configuration utilisateur. Ce fichier de configuration contient toutes les informations nécessaire pour authentifier l’utilisateur auprès du cluster. Vous pouvez utiliser la configuration de l’administrateur du cluster comme template. Il se trouve normalement dans /etc/kubernetes/. Les variables “certificate-authority-data” et “server” doivent être identiques à celle de l’administrateur.

```
apiVersion: v1
clusters:
- cluster:
 certificate-authority-data: {Parse content here}
 server: {Parse content here}
name: kubernetes
contexts:
- context:
 cluster: kubernetes
 user: geraldderive
name: geraldderive-context
current-context: geraldderive-context
kind: Config
preferences: {}
users:
- name: geraldderive
user:
 client-certificate: /home/geraldderive/.certs/geraldderive.cert
 client-key: /home/geraldderive/.certs/geraldderive.key
```

- Ensuite, nous devons copier la configuration ci-dessus dans le répertoire .kube.

```
mkdir .kube && vi .kube/config
```

- Appliquer les permission sur tous les fichiers et répertoires associés à l’utilisateur :

```
chown -R geraldderive: /home/geraldderive/
```

- Création du namespace et on vérifie si l'utilisateur peut éffeectuer les commandes qui lui sont interdites.



****
**Optionnel**
****

## 🖥️ Monitoring 🖥️



## 🔐 OIDC (OpenID Connect) 🔐



## 🧧 Registry + GUI Web (Graphical User Interface Web) 🧧

## Annexes

### Membres dux projet

- Guillaume LE COQ
- Benoit GALMOT
- Souleimane SEGHIR

### Plugins Kubernetes utilisés

#### Kubens / Kubectx

https://github.com/ahmetb/kubectx

```
sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens```