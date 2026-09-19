# ansible-linux-baseline

[![CI](https://github.com/dhanalakshmi11p/ansible-linux-baseline/actions/workflows/ci.yml/badge.svg)](https://github.com/dhanalakshmi11p/ansible-linux-baseline/actions)

Reusable Ansible roles that create users and harden SSH on Linux servers.
Built to replace repetitive, ticket-driven tasks with playbooks that are safe to
re-run and easy for any teammate to use.

## Why I built it

On a large server fleet the same requests come up again and again: create a
user, enforce a password policy, lock down SSH. Doing this by hand is slow and
inconsistent. These roles turn that work into a few minutes of automation and
leave every server in the same known state.

## What is inside

| Role              | What it does                                                             |
|-------------------|--------------------------------------------------------------------------|
| `user_management` | Creates or removes users, adds groups, enforces a password maximum age   |
| `ssh_hardening`   | Disables root login and X11 forwarding, limits auth tries, sets timeouts |

Design choices:

- **Idempotent.** Running a playbook twice changes nothing the second time.
- **Safe defaults.** Password login stays enabled until you switch it off, so you
  cannot lock yourself out by accident.
- **Validated changes.** SSH config is checked with `sshd -t` before it is applied.
- **Drop-in file.** SSH settings go in `/etc/ssh/sshd_config.d/00-hardening.conf`
  instead of editing the main config, so they take priority over distro defaults
  and are easy to review or remove.

## Requirements

- Ansible 2.14 or newer (`ansible-core` is enough, no extra collections)
- Target hosts: RHEL, Rocky, Alma, CentOS 8+ or Ubuntu 20.04+ (they support
  `sshd_config.d` drop-ins)
- SSH access to the targets and `sudo` rights

Tested on: _add your test VM's OS here, for example RHEL 9.3_

## Quick start

```bash
git clone https://github.com/dhanalakshmi11p/ansible-linux-baseline.git
cd ansible-linux-baseline

cp inventory/hosts.example.ini inventory/hosts.ini   # put your test VM here
# edit group_vars/all.yml to set your users and SSH settings

ansible-playbook -i inventory/hosts.ini site.yml -K --check --diff   # preview
ansible-playbook -i inventory/hosts.ini site.yml -K                  # apply
```

Run only one part with tags: `--tags users` or `--tags ssh`.

## Verify the result

```bash
sudo sshd -T | grep -Ei 'permitrootlogin|x11forwarding|maxauthtries|clientalive'
cat /etc/ssh/sshd_config.d/00-hardening.conf
id test1
sudo chage -l test1 | grep Maximum
```

Expected SSH values after a run with the default settings:

```
maxauthtries 4
clientaliveinterval 300
clientalivecountmax 2
permitrootlogin no
x11forwarding no
```

Run the playbook a second time. The recap should show `changed=0`, which proves
the roles are idempotent.

## Configuration

Common variables (see `roles/*/defaults/main.yml` for the full list):

| Variable                                 | Default | Purpose                                  |
|------------------------------------------|---------|------------------------------------------|
| `ssh_hardening_permit_root_login`        | `no`    | Block direct root login                  |
| `ssh_hardening_password_authentication`  | `yes`   | Set to `no` once SSH keys are working    |
| `ssh_hardening_max_auth_tries`           | `4`     | Failed attempts per connection           |
| `user_management_users`                  | `[]`    | List of users (name, groups, state)      |
| `user_management_password_max_days`      | `90`    | Maximum password age                     |

Example user list in `group_vars/all.yml`:

```yaml
user_management_users:
  - name: test1
    groups: [wheel]      # use [sudo] on Debian/Ubuntu
    state: present
  - name: olduser
    state: absent        # removes the account and its home directory
```

## Safety notes

- Keep a second SSH session open while you apply SSH changes.
- Do not set `ssh_hardening_password_authentication: "no"` until key-based login
  works for your account.
- Try `--check --diff` first to preview every change.

## Quality checks

Every push runs `yamllint`, `ansible-lint` and a playbook syntax check through
GitHub Actions. Locally:

```bash
pip install ansible-core ansible-lint yamllint
yamllint . && ansible-lint
```

## Ideas for next steps

- Add a read-only compliance audit role that reports PASS or FAIL per control
- Add a firewall role (firewalld or ufw)
- Add an idempotence test in CI using Molecule or a container
- Add SSH public key deployment to `user_management`

## License

MIT
