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



## 🗃️ KubeBD 🗃️



## 🌐 Wordpress 🌐



## 🧔 RBAC (Role-Based Access Control) 🧔



****
**Optionnel**
****

## Monitoring



## OIDC



## Registry + GUI Web


## Annexes

### Membres du projet

- Guillaume LE COQ
- Benoit GALMOT
- Souleimane SEGHIR