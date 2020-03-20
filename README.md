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



Pour définir le mot de passe de l'utilisateur root il nous faut créer un secret.

```bash
kubectl create secret generic m1-auth \
--from-literal=user=root \
--from-literal=password=password

secret "m1-auth" created
```

**revoir création secret
kubectl get dormantdatabase**

#### Initialiser base de donnée via script SQL / Snapshot



## 🌐 Wordpress 🌐

https://kubernetes.io/docs/tutorials/stateful-application/mysql-wordpress-persistent-volume/

- script création utilisateur + Database
- création kubedb mysql
- création secret user wordpress
- création déploiement + service wordpress
- connexion

## 🧔 RBAC (Role-Based Access Control) 🧔



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