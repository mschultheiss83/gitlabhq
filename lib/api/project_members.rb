module API
  # Projects members API
  class ProjectMembers < Grape::API
    before { authenticate! }

    resource :projects do
      helpers do
        def handle_project_member_errors(errors)
          if errors[:access_level].any?
            error!(errors[:access_level], 422)
          end
          not_found!(errors)
        end
      end

      # Get a project team members
      #
      # Parameters:
      #   id (required) - The ID of a project
      #   query         - Query string
      # Example Request:
      #   GET /projects/:id/members
      get ":id/members" do
        if params[:query].present?
          @members = paginate user_project.users.where("username LIKE ?", "%#{params[:query]}%")
        else
          @members = paginate user_project.users
        end
        present @members, with: Entities::ProjectMember, project: user_project
      end

      # Get a project team members
      #
      # Parameters:
      #   id (required) - The ID of a project
      #   user_id (required) - The ID of a user
      # Example Request:
      #   GET /projects/:id/members/:user_id
      get ":id/members/:user_id" do
        @member = user_project.users.find params[:user_id]
        present @member, with: Entities::ProjectMember, project: user_project
      end

      # Add a new project team member
      #
      # Parameters:
      #   id (required) - The ID of a project
      #   user_id (required) - The ID of a user
      #   access_level (required) - Project access level
      # Example Request:
      #   POST /projects/:id/members
      post ":id/members" do
        authorize! :admin_project, user_project
        required_attributes! [:user_id, :access_level]

        # either the user is already a team member or a new one
        team_member = user_project.team_member_by_id(params[:user_id])
        if team_member.nil?
          team_member = user_project.project_members.new(
            user_id: params[:user_id],
            access_level: params[:access_level]
          )
        end

        if team_member.save
          @member = team_member.user
          present @member, with: Entities::ProjectMember, project: user_project
        else
          handle_project_member_errors team_member.errors
        end
      end

      # Update project team member
      #
      # Parameters:
      #   id (required) - The ID of a project
      #   user_id (required) - The ID of a team member
      #   access_level (required) - Project access level
      # Example Request:
      #   PUT /projects/:id/members/:user_id
      put ":id/members/:user_id" do
        authorize! :admin_project, user_project
        required_attributes! [:access_level]

        team_member = user_project.project_members.find_by(user_id: params[:user_id])
        not_found!("User can not be found") if team_member.nil?

        if team_member.update_attributes(access_level: params[:access_level])
          @member = team_member.user
          present @member, with: Entities::ProjectMember, project: user_project
        else
          handle_project_member_errors team_member.errors
        end
      end

      # Remove a team member from project
      #
      # Parameters:
      #   id (required) - The ID of a project
      #   user_id (required) - The ID of a team member
      # Example Request:
      #   DELETE /projects/:id/members/:user_id
      delete ":id/members/:user_id" do
        authorize! :admin_project, user_project
        team_member = user_project.project_members.find_by(user_id: params[:user_id])
        unless team_member.nil?
          team_member.destroy
        else
          { message: "Access revoked", id: params[:user_id].to_i }
        end
      end
    end
  end
end
