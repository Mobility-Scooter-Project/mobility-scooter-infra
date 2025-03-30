# Mobility Scooter Project Infra
This repo stores all the infrastructure bootstraping configurations for the Mobility Scooter Project led by Dr. Tingten Chen at Cal Poly Pomona. The end goal of this is to provide self-service capabilities for any team within the Mobility Scooter Project.

Below is a brief list of technologies used by in this repo. For a more detailed overview, please see the [wiki](https://github.com/Mobility-Scooter-Project/mobility-scooter-infa/wiki).

## Technologies
- [Openstack](https://docs.openstack.org/2024.1/)
- Terraform
    - [Terraform Cloud Development Kit (CDKTF)](https://developer.hashicorp.com/terraform/cdktf)
- [K3s](https://docs.k3s.io/)
    - [Traefik](https://doc.traefik.io/traefik/providers/kubernetes-crd/)
    - [cert-manager](https://cert-manager.io/)
    - [Headlamp](https://headlamp.dev/)
    - [ArgoCD](https://argo-cd.readthedocs.io/en/stable/)
    - [Kargo](https://kargo.io/)

**Note:** Scripts in this repo are intended to be run via _cdktf deploy only_