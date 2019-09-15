#!/usr/bin/env bats

load 'test/helpers/assert/load'
load 'test/helpers/support/load'
load 'test/helpers/mocks/stub'

setup() {
  # There might be leftovers from previous runs.
  for stub in tracer systemctl; do
    unstub "$stub"  2> /dev/null || true
  done
}

teardown() {
  for stub in tracer systemctl; do
    unstub "$stub" || true
  done
}

@test 'help requested' {
  stub tracer ': exit 127'

  run ./dnf-automatic-restart -h

  assert_success
  assert_line --partial 'Usage: dnf-automatic-restart'
}

@test 'tracer not installed' {
  stub tracer ': exit 127'

  run ./dnf-automatic-restart

  assert_failure 127
}

@test 'tracer fails with code 1' {
  stub tracer ': exit 1'

  run ./dnf-automatic-restart

  assert_failure 1
}

@test 'tracer fails with code < 101' {
  stub tracer ': exit 100'

  run ./dnf-automatic-restart

  assert_failure 100
}

@test 'tracer fails with code > 104' {
  stub tracer ': exit 105'

  run ./dnf-automatic-restart

  assert_failure 105
}

@test 'kernel was updated, reboots are disabled' {
  services_are_restarted="$(mktemp)"

  stub tracer \
         ': exit 104' \
         "--services-only : echo true > '$services_are_restarted'"

  run ./dnf-automatic-restart -d

  assert_success
  assert_line 'The kernel was updated'
  assert_line 'Rebooting is disabled'

  assert grep --quiet true "$services_are_restarted"
}

@test 'systemd was updated, reboots are disabled' {
  services_are_restarted="$(mktemp)"

  stub tracer \
         ': echo systemd' \
         "--services-only : echo true > '$services_are_restarted'"

  run ./dnf-automatic-restart -d

  assert_success
  assert_line 'systemd was updated'
  assert_line 'Rebooting is disabled'

  assert grep --quiet true "$services_are_restarted"
}

# @test 'reboot requested outside of allowed hours'{

# }

@test 'no services were updated' {
  tracer_services="ignored line\nignored line"

  stub tracer \
         ': exit 0' \
         "--services-only : printf '$tracer_services'"

  run ./dnf-automatic-restart

  assert_success
}

@test 'services were updated' {
  tracer_services="ignored line\nignored line\nsystemctl restart z-ordered-last\nsystemctl restart a-ordered-first"

  stub tracer \
         ': exit 0' \
         "--services-only : printf '$tracer_services'"

  stub systemctl

  run ./dnf-automatic-restart

  assert_success
  assert_line 'Reloading systemd daemon configuration'
  assert_line 'Restarting service using systemctl restart a-ordered-first'
  assert_line 'Restarting service using systemctl restart z-ordered-last'

  # systemd daemon configuration should only be reloaded once.
  assert_line 'Reloading systemd daemon configuration'
  refute_output --regexp 'Reloading systemd daemon configuration.*Reloading systemd daemon configuration'

  # Services should be sorted.
  assert_output --regexp 'a-ordered-first.*z-ordered-last'
}

@test 'services restarts are surrounded by whitespace' {
  tracer_services="ignored line\nignored line\n   systemctl restart foo   "

  stub tracer \
         ': exit 0' \
         "--services-only : printf '$tracer_services'"

  stub systemctl

  run ./dnf-automatic-restart

  assert_success
  assert_line 'Reloading systemd daemon configuration'
  assert_line 'Restarting service using systemctl restart foo'
}

@test 'services require restart that but fail partially' {
  tracer_services="ignored line\nignored line\nsystemctl restart success\nsystemctl restart failure"

  stub tracer \
         ': exit 0' \
         "--services-only : printf '$tracer_services'"

  stub systemctl \
         'is-active --quiet docker : exit 0' \
         'daemon-reload : exit 0' \
         'restart failure : exit 42' \
         'restart success : exit 0'

  run ./dnf-automatic-restart

  assert_success
  assert_line 'systemctl restart failure failed with exit code 42'
}

@test 'firewalld was updated but docker is not active' {
  tracer_services="ignored line\nignored line\n   systemctl restart firewalld"

  stub tracer \
         ': exit 0' \
         "--services-only : printf '$tracer_services'"

  docker_restarted="$(mktemp)"
  stub systemctl \
         'is-active --quiet docker : exit 1' \
         'daemon-reload : exit 0' \
         'restart firewalld : exit 0' \
         "restart docker : echo true > '$docker_restarted'"

  run ./dnf-automatic-restart

  assert_success
  refute_line --partial 'docker'
  refute grep --quiet true "$docker_restarted"
}

@test 'firewalld was updated and docker is active' {
  tracer_services="ignored line\nignored line\n   systemctl restart firewalld"

  stub tracer \
         ': exit 0' \
         "--services-only : printf '$tracer_services'"

  docker_restarted="$(mktemp)"
  stub systemctl \
         'is-active --quiet docker : exit 0' \
         'daemon-reload : exit 0' \
         'restart firewalld : exit 0' \
         "restart docker : echo true > '$docker_restarted'"

  run ./dnf-automatic-restart

  assert_success
  assert grep --quiet true "$docker_restarted"

  # Restart docker after firewalld.
  assert_output --regexp 'firewalld.*docker'
}

@test 'firewalld and docker were updated and docker is active' {
  tracer_services="ignored line\nignored line\n   systemctl restart firewalld\n   systemctl restart docker"

  stub tracer \
         ': exit 0' \
         "--services-only : printf '$tracer_services'"

  docker_restarted="$(mktemp)"
  stub systemctl \
         'is-active --quiet docker : exit 0' \
         'daemon-reload : exit 0' \
         "restart firewalld : exit 0" \
         "restart docker : echo once > '$docker_restarted'" \
         "restart docker : echo twice > '$docker_restarted'"

  run ./dnf-automatic-restart

  assert_success
  assert grep --quiet once "$docker_restarted"

  # Restart docker after firewalld.
  assert_output --regexp 'firewalld.*docker'
}
