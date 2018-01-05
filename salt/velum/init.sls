include:
  - etc-hosts
  - ca-cert
  - cert

{% set names = [salt.caasp_pillar.get('dashboard_external_fqdn'),
                salt.caasp_pillar.get('dashboard')] %}

{% from '_macros/certs.jinja' import alt_names, certs with context %}
{{ certs("velum:" + grains['host'],
         pillar['ssl']['velum_crt'],
         pillar['ssl']['velum_key'],
         cn = grains['host'],
         extra_alt_names = alt_names(names)) }}
