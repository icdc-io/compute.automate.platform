#############################
# ahrechushkin: The main goal of this module is looking for frozen and stucked backup objects.
# When the objects was found we want to go ahead two ways:
# 1. If possible - resume backup process
# 2. Otherwise unlock service, fail backup and optionaly notify operators' about some problems in location
##############################
module Platform
  module Automation
    module System
      module Methods
        class BackupsWatchdog
          def initialize(handle = $evm)
            @handle = handle
            @max_hours = 4
            @start_time = DateTime.now
            @notifications = true
            @broken_backups = []
            @resumed_on_snapshot_phase = []
            @resumed_on_template_phase = []
          end

          def perform
            @handle.log(:info, "[Backups Watchdog] started at #{DateTime.now}")
            @handle.log(:info, "#{@max_hours} :: #{@notifications}")
            backups = stucked_backups
            @handle.log(:info,
                        "[Backups Watchdog] Found #{backups.size} stucked backups from #{DateTime.now - @max_hours.hours} to #{@start_time - (@max_hours + 1).hours}")

            backups.each do |backup|
              @handle.log(:info, "[Backups Watchdog] Analyze backup #{backup.name} (#{backup.id})")
              case backup.status
              when /snapshot/
                snapshot_phase(backup)
              when /template/
                template_phase(backup)
              else
                @broken_backups << backup
              end
            end

            notify_admins
          end

          private

          def stucked_backups
            @handle.vmdb(:GenericObject).where(
              generic_object_definition_id: Backup.id,
              created_at: (@start_time - @max_hours.hours)..@start_time  - (@max_hours + 1).hours
            ).select { |x| x unless %w[ready locked error].include?(x.status) || x.terminated || x.error }
          end

          def snapshot_phase(backup)
            snapshot_uuid = backup.snapshot_uuid
            unless snapshot_uuid
              @broken_backups << backup
              return
            end
            snapshot = $evm.vmdb(:Snapshot).find_by(description: snapshot_uuid)
            template = $evm.vmdb(:VmOrTemplate).find_by(name: backup.name)

            if template
              template_phase(backup, template)
              return
            elsif snapshot

              vm = $evm.vmdb(:Vm).find_by!(name: JSON.parse(backup.configuration)['vm_name'])
              connection = establish_connection(vm)
              create_template(connection, vm, backup)
            else
              vm = $evm.vmdb(:Vm).find_by!(name: JSON.parse(backup.configuration)['vm_name'])
              create_snapshot(vm, backup)
            end

            @resumed_on_snapshot_phase << backup
          rescue StandardError => e
            $evm.log(:error, "[BackupsWatchdog] can't resume backup #{backup.name}(#{backup.id}) on snapshot phase
                    #{e.message}")
            @broken_backups << backup
          end

          def template_phase(backup, template = nil)
            template ||= $evm.vmdb(:VmOrTemplate).find_by(name: backup.name)

            if template
              @handle.vmdb(:Snapshot).find_by(description: backup.snapshot_uuid).remove
              backup.template = [template]
              backup.error = false
              backup.template = false
              backup.status = 'ready'
              backup.save!
            else
              vm = $evm.vmdb(:Vm).find_by!(name: JSON.parse(backup.configuration)['vm_name'])
              connection = establish_connection(vm)
              create_template(connection, vm, backup)
            end

            @resumed_on_template_phase << bakup
          rescue StandardError => e
            $evm.log(:error, "[BackupsWatchdog] can't resume backup #{backup.name}(#{backup.id}) on template phase
                    #{e.message}")
          end

          def notify_admins
            if @broken_backups.count > 0 || if @resumed_on_template_phase.count > 0 || if @resumed_on_snapshot_phase.count > 0
                  @handle.instantiate('/Configuration/Email/Default')
                  email_attributes = @handle.object('/Configuration/Email/Default').attributes
                  from = email_attributes['from'].to_s
                  to = email_attributes['default_recipient'].to_s
                  subject = "[Compute] Backups WatchDog report #{DateTime.now.strftime('%FT%H:%M')}"
                  message_body = "<p>The Backup Watchdog looked for stuck backups created in the time period of #{@start_time - @max_hours.hours} and #{@start_time - @max_hours.hours + 1.hour}</p>"
                  message_body += "<p>Found stucked backups: #{@broken_backups.count + @resumed_on_snapshot_phase.count + @resumed_on_template_phase.count}</p>"
                  if @resumed_on_snapshot_phase.count > 0
                    message_body += "<p><b>Resumed on snapshot phase: #{@resumed_on_snapshot_phase.count}</b></p><br>"
                    message_body += "<table border='1'>"
                    message_body += '<tr><td><b>Backup name</b></td><td><b>Backup ID</b></td></tr>'
                    @resumed_on_snapshot_phase.each do |backup|
                      message_body += "<tr><td>#{backup.name}</td><td>#{backup.id}</td></tr>"
                    end
                    message_body += '</table><br>'
                  end

                  if @resumed_on_template_phase.count > 0
                    message_body += "<p><b>Resumed on template phase - #{@resumed_on_template_phase.count}</b></p>"
                    message_body += "<table border='1'>"
                    message_body += '<tr><td><b>Backup name</b></td><td><b>Backup ID</b></td></tr>'
                    @resumed_on_template_phase.each do |backup|
                      message_body += "<tr><td>#{backup.name}</td><td>#{backup.id}</td></tr>"
                    end
                    message_body += '</table><br>'
                  end

                  if @broken_backups.count > 0
                    message_body += "<p><b>Broken backups - #{@broken_backups.count}</b></p>"
                    message_body += "<table border='1'>"
                    message_body += '<tr><td><b>Backup name</b></td><td><b>Backup ID</b></td></tr>'
                    @broken_backups.each do |backup|
                      message_body += "<tr><td>#{backup.name}</td><td>#{backup.id}</td></tr>"
                    end
                    message_body += '</table><br>'
                  end

                  message_body += "<p>How to fix broken backups: https://portal.#{ENV.fetch("CPV_DOMAIN", nil)}/services/compute/backups/troubleshoot/backup_problem.html</p>"
                  message_body += email_attributes['signature']
                  @handle.execute('send_email',
                    to, from, subject, message_body)
                end
              end
            end
          end
        end
      end
    end
  end
end

Platform::Automation::System::Methods::BackupsWatchdog.new.perform
