# frozen_string_literal: true

module API
  module V2
    module Admin
      # Admin functionality over jobs table
      class Jobs < Grape::API
        resource :jobs do
          helpers ::API::V2::NamedParams

          desc 'Create new job',
            failure: [
              { code: 401, message: 'Invalid bearer token' }
            ],
            success: { code: 200, message: 'Job was created' }
          params do
            requires :description,
                     type: String,
                     allow_blank: false,
                     desc: 'job description'
            requires :type,
                     type: String,
                     values: { value: -> { ['maintenance'] }, message: 'admin.job.invalid_type'},
                     desc: 'job type'
            requires :start_at,
                     type: DateTime,
                     desc: 'time to run start job'
            requires :finish_at,
                     type: DateTime,
                     desc: 'time to run finish job'
            optional :whitelist_ip,
                     type: Array[String],
                     desc: 'whitelist IP addresses'
          end
          post do
            admin_authorize! :create, Job
            admin_authorize! :create, Restriction
            admin_authorize! :create, Jobbing
            
            # Create or find maintenace restriction
            maintenance = Restriction.find_or_create_by(category: params[:type], scope: 'all', value: 'all', state: 'disabled')

            # Set parameters
            declared_params = declared(params, include_missing: false)
            job_params = declared_params.except(:whitelist_ip)

            # Create new job
            job = Job.new(job_params)
            code_error!(job.errors.details, 422) unless job.save

            # Create maintenance job
            Jobbing.create!(job: job, reference: maintenance)

            # Create new whitelist jobs
            if params[whitelist_ip].present?
              params[whitelist_ip].each do |ip|
                whitelist = Restriction.create!(scope: 'ip', category: 'whitelist', value: ip)
                Jobbing.create!(job: job, reference: whitelist)
              end
            end

            # clear cached restrictions, so they will be freshly refetched on the next call to /auth
            Rails.cache.delete('restrictions')

            status 200
          end

          # GET request
          # List for existing Jobs with pagination

          # PUT request
          # Update of existing Job mainly it will be used to disable Job and disable reference
          # Also, we can add here the ability to change starts_at and finish_at (Bonus Task)
        end
      end
    end
  end
end
