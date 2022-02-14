{% set salt_tag = '0.0.2' %}
{% set force = False %}
{% set salt_minion = 'salt-minion' %}
{% set schedule_interval = '1' %}
{% set salt_repo = 'Z:\salt_win'%}
{% set vault_local_prod_path = 'C:\\vault\\prod' %}
{% set vault_local_prod_bin_path = vault_local_prod_path + '\\head\\bin' %}
{% set schedule_script_name = 'salt-minion-schedule.bat' %}
{% set salt_envs_script_name = 'salt-envs.bat' %}
{% set salt_copy_stat_file_name = 'copy_state' %}
{% set salt_minion_script_name = salt_minion + '.bat' %}
{% set salt_miniond_script_name = salt_minion + 'd.bat' %}
{% set salt_fallback_script_name = 'salt_fallback.bat' %}

{% set salt_install_dir = vault_local_prod_path + '\softwares\dev\saltstack' %}
{% set salt_install_root = salt_install_dir + '\\' + salt_tag %}
{% set config_install_dir = salt_install_root + '\\' + 'config' %}
{% set logs_install_dir = salt_install_root + '\\logs' %}
{% set salt_copy_stat_file = salt_install_root + '\\' + salt_copy_stat_file_name %}
{% set salt_envs_script = salt_install_root + '\\' + salt_envs_script_name %}
{% set salt_envs_head_script = vault_local_prod_bin_path + '\\' + salt_envs_script_name %}
{% set salt_miniond_script = salt_install_root + '\\' + salt_miniond_script_name %}
{% set salt_miniond_head_script = vault_local_prod_bin_path + '\\' + salt_miniond_script_name %}

{% set salt_fallback_script = salt_install_root + '\\' + salt_fallback_script_name %}
{% set salt_fallback_head_script = vault_local_prod_bin_path + '\\' + salt_fallback_script_name %}

{% set salt_schedule_script = salt_install_root + '\\' + schedule_script_name %}
{% set salt_schedule_head_script = vault_local_prod_bin_path + '\\' + schedule_script_name %}

{% set salt_grain_conf = salt_install_root + '\\config\\minion.d\\_salt_tag.conf' %}
{% set log_file = logs_install_dir + '\\minion' %}
{% set service_manager = salt_install_root + '\\bin\\ssm.exe' %}
{% set service_manager_head = vault_local_prod_bin_path + '\\ssm.exe' %}

{% set copy_stat_exists = salt.file.file_exists(salt_copy_stat_file) %}
{% if copy_stat_exists == False or force == True %}

copy_salt:
  file.copy:
    - name: '{{ salt_install_root }}'
    - source: '{{ salt_repo }}\{{ salt_tag }}'
    - subdirs: True
    - force: True

create_copy_stat_file:
    file.managed:
    - name: '{{ salt_copy_stat_file }}'
    - create: True
    - makedirs: True
    - contents:
      - ''
{% endif %}

create_local_prod_bin_dir:
  file.directory:
    - name: '{{ vault_local_prod_bin_path }}'
    - makedirs: True

create_config_dir:
  file.directory:
    - name: '{{ config_install_dir }}'
    - makedirs: True

create_logs_dir:
  file.directory:
    - name: '{{ logs_install_dir }}'
    - makedirs: True

write_salt_env_script:
  file.managed:
    - name: '{{ salt_envs_script }}'
    - create: True
    - makedirs: True
    - contents:
      - 'setx PYTHONPATH ""'

copy_env_head_script:
  file.managed:
      - name: '{{ salt_envs_head_script }}'
      - source: '{{ salt_envs_script }}'
      - create: True
      - makedirs: True

write_miniond_script:
  file.managed:
      - name: '{{ salt_miniond_script }}'
      - create: True
      - makedirs: True
      - contents:
        - 'call {{ salt_envs_head_script }}'
        - '{{ salt_install_root }}\{{ salt_minion_script_name }} -l debug -c {{ config_install_dir }} --log-file {{ log_file }}'

copy_miniond_head_script:
  file.managed:
      - name: '{{ salt_miniond_head_script }}'
      - source: '{{ salt_miniond_script }}'
      - create: True
      - makedirs: True

write_tag_grain_file:
  file.managed:
    - name: '{{ salt_grain_conf }}'
    - create: True
    - makedirs: True
    - contents:
      - 'grains: {salt_tag: {{ salt_tag}} }'

copy_service_manager_head:
  file.managed:
    - name: '{{ service_manager_head }}'
    - source: '{{ service_manager }}'
    - create: True
    - makedirs: True
      
{% set orig_salt_miniond_script = salt['cmd.run'](service_manager_head + ' ' + 'get' + ' ' + salt_minion + ' ' + 'application') %}
{% set orig_salt_install_root = salt['file.dirname'](orig_salt_miniond_script) %}
{% set orig_salt_envs_script = orig_salt_install_root + '\\' +  salt_envs_script_name %}
{% set orig_salt_schedule_script = orig_salt_install_root + '\\' +  schedule_script_name %}

{% if salt_miniond_script != orig_salt_miniond_script %}

print:
  cmd.run:
    - name: 'echo {{ orig_salt_install_root }} {{ orig_salt_envs_script }} {{ orig_salt_schedule_script }}'

create_fallback_script:
  file.managed:
    - name: '{{ salt_fallback_script }}'
    - create: True
    - makedirs: True
    - contents:
      - 'copy /y {{ orig_salt_envs_script }} {{ salt_envs_head_script }}'
      - 'copy /y {{ orig_salt_miniond_script }} {{ salt_miniond_head_script }}'
      - 'copy /y {{ orig_salt_schedule_script }} {{ salt_schedule_head_script }}'

create_checkpoint_file:
  file.managed:
    - name: 
    - contents:
      - '0'
      
copy_schedule_head_script:
  file.managed:
    - name: '{{ salt_schedule_head_script }}'
    - source: '{{ salt_schedule_script }}'
    - create: True
    - makedirs: True

{% endif %}