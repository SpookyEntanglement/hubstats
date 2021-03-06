require_dependency "hubstats/application_controller"

module Hubstats
  class ReposController < ApplicationController

    # Public - Shows all of the repos, in either alphabetical order, by filter params, or that have done things in
    # github between the selected @start_date and @end_date.
    #
    # Returns - the repository data
    def index
      if params[:query] ## For select 2
        @repos = Hubstats::Repo.where("name LIKE ?", "%#{params[:query]}%").order("name ASC")
      elsif params[:id]
        @repos = Hubstats::Repo.where(id: params[:id].split(",")).order("name ASC")
      else
        @repos = Hubstats::Repo.with_all_metrics(@start_date, @end_date)
          .with_id(params[:repos])
          .custom_order(params[:order])
          .paginate(:page => params[:page], :per_page => 15)
      end

      respond_to do |format|
        format.html
        format.json { render :json => @repos}
      end
    end

    # Public - Shows the selected repository and all of the basic stats associated with that repository, including
    # all deploys and merged PRs in that repo within @start_date and @end_date.
    #
    # Returns - the specific repository data
    def show
      @repo = Hubstats::Repo.where(name: params[:repo]).first
      @pull_requests = Hubstats::PullRequest.belonging_to_repo(@repo.id).merged_in_date_range(@start_date, @end_date).order("updated_at DESC").limit(20)
      @pull_count = Hubstats::PullRequest.belonging_to_repo(@repo.id).merged_in_date_range(@start_date, @end_date).count(:all)
      @deploys = Hubstats::Deploy.belonging_to_repo(@repo.id).deployed_in_date_range(@start_date, @end_date).order("deployed_at DESC").limit(20)
      @deploy_count = Hubstats::Deploy.belonging_to_repo(@repo.id).deployed_in_date_range(@start_date, @end_date).count(:all)
      @comment_count = Hubstats::Comment.belonging_to_repo(@repo.id).created_in_date_range(@start_date, @end_date).count(:all)
      @active_user_count = Hubstats::User.with_pulls_or_comments_or_deploys(@start_date, @end_date, @repo.id).only_active.length
      @net_additions = Hubstats::PullRequest.merged_in_date_range(@start_date, @end_date).belonging_to_repo(@repo.id).sum(:additions).to_i -
                       Hubstats::PullRequest.merged_in_date_range(@start_date, @end_date).belonging_to_repo(@repo.id).sum(:deletions).to_i
      @additions = Hubstats::PullRequest.merged_in_date_range(@start_date, @end_date).belonging_to_repo(@repo.id).average(:additions)
      @deletions = Hubstats::PullRequest.merged_in_date_range(@start_date, @end_date).belonging_to_repo(@repo.id).average(:deletions)      

      stats
    end

    # Public - Will assign all of the stats for both the show page and the dashboard page.
    #
    # Returns - the data in two hashes
    def stats
      @additions ||= 0
      @deletions ||= 0
      @stats_row_one = {
        active_user_count: @active_user_count,
        deploy_count: @deploy_count,
        pull_count: @pull_count,
        comment_count: @comment_count
      }
      @stats_row_two = {
        avg_additions: @additions.round.to_i,
        avg_deletions: @deletions.round.to_i,
        net_additions: @net_additions
      }
    end
  end
end
