# KubeWorld

![image alt](https://d33wubrfki0l68.cloudfront.net/69e55f968a6f44613384615c6a78b881bfe28bd6/42cd3/_common-resources/images/flower.svg)

## ✂️ Découpage de l'infrastructure ✂️

Le découpage de l'infrastructure serait d'**un namespace par client**.
Ce choix est guidé par la volonté de garder les environements des clients indépendant des uns des autres.
Autrement dit, si un l'environnement du **client A** pose problème, il ne pourra impacter le bon fonctionnement de l'environnement du **client B**.



## 🔌 Démarrage du Projet Rockstar 🔌



On va dans le dossier contenant le projet exemple.

``````
cd ./RockStartConfig\Rockstar-With-KubeDB
``````



On met en place le `namespace` et son `quotas`.

``````
kubectl apply -f namespace.yaml
kubectl apply -f ressource-quotas.yaml
``````



On met en place le `configMap` contenant le `script` d'initialisation de la base de données wordpress.

``````
kubectl create -f mysql-elements.yaml
``````



On met en place le Mysql. 

``````
kubedb create -f mysql-deployment.yaml
``````



Enfin, on lance le wordpress.

``````
kubectl create -f wordpress-auth-mysql.yaml
kubectl create -f wordpress-deployment.yaml
``````



On récupère l'ip du` LoadBalancer`  wordpress que l'on va mettre dans notre navigateur.

``````
sudo minikube service wordpress -n rockstar-namespace --url
``````

