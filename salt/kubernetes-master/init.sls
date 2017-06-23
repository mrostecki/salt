include:
  - repositories
  - ca-cert
  - cert
  - etcd
  - kubernetes-common

{% set api_ssl_port = salt['pillar.get']('api:ssl_port', '6443') %}

#######################
# components
#######################

kubernetes-master:
  pkg.installed:
    - pkgs:
      - iptables
      - etcdctl
      - kubernetes-client
      - kubernetes-master
    - require:
      - file: /etc/zypp/repos.d/containers.repo

/etc/systemd/system/kube-apiserver.service.d/apiserver-restarts.conf:
  file.managed:
    - source: salt://kubernetes-master/apiserver-restarts.conf
    - makedirs: True
    - cmd.run:
      - name: systemctl daemon-reload
      - stateful: True
    - require:
      - pkg: kubernetes-master

kube-apiserver:
  iptables.append:
    - table:      filter
    - family:     ipv4
    - chain:      INPUT
    - jump:       ACCEPT
    - match:      state
    - connstate:  NEW
    - dports:
        - {{ api_ssl_port }}
    - proto:      tcp
    - require:
      - pkg:      kubernetes-master
  file.managed:
    - name:       /etc/kubernetes/apiserver
    - source:     salt://kubernetes-master/apiserver.jinja
    - template:   jinja
    - require:
      - pkg:      kubernetes-master
  service.running:
    - enable:     True
    - require:
      - pkg:      kubernetes-master
      - iptables: kube-apiserver
      - sls:      ca-cert
      - sls:      cert
    - watch:
      - file:     /etc/kubernetes/config
      - file:     kube-apiserver
      - sls:      ca-cert
      - sls:      cert

kube-scheduler:
  file.managed:
    - name:       /etc/kubernetes/scheduler
    - source:     salt://kubernetes-master/scheduler.jinja
    - template:   jinja
    - require:
      - pkg:      kubernetes-master
  service.running:
    - enable:     True
    - watch:
      - file:     /etc/kubernetes/config
      - file:     kube-scheduler

kube-controller-manager:
  file.managed:
    - name:       /etc/kubernetes/manifests/controller-manager.yaml
    - source:     salt://kubernetes-master/controller-manager.yaml.jinja
    - template:   jinja
    - require:
      - pkg:      kubernetes-master

###################################
# addons
###################################

{% if pillar.get('addons', '').lower() == 'true' %}

/root/namespace.yaml:
  file.managed:
    - source:      salt://kubernetes-master/addons/namespace.yaml.jinja
    - template:    jinja

/root/skydns-rc.yaml:
  file.managed:
    - source:      salt://kubernetes-master/addons/skydns-rc.yaml.jinja
    - template:    jinja

/root/skydns-svc.yaml:
  file.managed:
    - source:      salt://kubernetes-master/addons/skydns-svc.yaml.jinja
    - template:    jinja

deploy_addons.sh:
  cmd.script:
    - source:      salt://kubernetes-master/deploy_addons.sh
    - require:
      - pkg:       kubernetes-master
      - service:   kube-apiserver
      - file:      /root/namespace.yaml
      - file:      /root/skydns-svc.yaml
      - file:      /root/skydns-rc.yaml

{% endif %}
