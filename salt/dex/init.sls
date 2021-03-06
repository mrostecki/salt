include:
  - crypto
  - repositories
  - kubectl-config
  - kube-apiserver

{% from '_macros/certs.jinja' import alt_master_names, certs with context %}
{% from '_macros/kubectl.jinja' import kubectl, kubectl_apply_template with context %}

{% set dex_alt_names = ["dex",
                        "dex.kube-system",
                        "dex.kube-system.svc",
                        "dex.kube-system.svc." + pillar['internal_infra_domain']] %}
{{ certs('dex',
         pillar['ssl']['dex_crt'],
         pillar['ssl']['dex_key'],
         cn = 'Dex',
         extra_alt_names = alt_master_names(dex_alt_names)) }}

{{ kubectl("dex_secrets",
           "create secret generic dex-tls --namespace=kube-system --from-file=/etc/pki/dex.crt --from-file=/etc/pki/dex.key",
           unless="kubectl get secret dex-tls --namespace=kube-system",
           check_cmd="kubectl get secret dex-tls --namespace=kube-system",
           require=["/etc/pki/dex.crt"]) }}

{{ kubectl_apply_template("salt://dex/dex.yaml",
                          "/root/dex.yaml",
                          watch=["dex_secrets", "/etc/pki/dex.crt"]) }}

{{ kubectl_apply_template("salt://dex/roles.yaml",
                          "/root/roles.yaml",
                          watch=["dex_secrets", "/root/dex.yaml"]) }}

ensure_dex_running:
  # Wait until the Dex API is actually up and running
  http.wait_for_successful_query:
    {% set dex_api_server = pillar['api']['server']['external_fqdn'] -%}
    {% set dex_api_port = pillar['dex']['node_port'] -%}
    - name:       {{ 'https://' + dex_api_server + ':' + dex_api_port }}/.well-known/openid-configuration
    - wait_for:   300
    - ca_bundle:  {{ pillar['ssl']['ca_file'] }}
    - status:     200
    - watch:
      - /root/dex.yaml
      - /root/roles.yaml
