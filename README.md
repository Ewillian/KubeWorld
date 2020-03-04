# KubeWorld

## Découpage de l'infrastructure

Le découpage de l'infrastructure serait d'**un namespace par client**.
Ce choix est guidé par la volonté de garder les environements des clients indépendant des uns des autres.
Autrement dit, si un l'environnement du **client A** pose problème, il ne pourra impacter le bon fonctionnement de l'environnement du **client B**.

A chaque namespace sera affecté un quota.
**Un namespace par client**
- Deployment
- Ingress
- Service
- Quota

