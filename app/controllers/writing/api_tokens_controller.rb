class Writing::ApiTokensController < ApplicationController
  layout "writing"

  # The plaintext token exists only in memory on the record that just saved it; we stash
  # it in the flash so the redirected Connect page can show it exactly once, then it's
  # gone — only the SHA256 digest is ever stored.
  def create
    @api_token = Current.user.api_tokens.build(api_token_params)

    if @api_token.save
      flash[:new_token] = @api_token.plain_token
      redirect_to writing_connect_url, notice: "Token created. Copy it now — it won't be shown again."
    else
      redirect_to writing_connect_url, alert: @api_token.errors.full_messages.to_sentence
    end
  end

  def destroy
    Current.user.api_tokens.find(params[:id]).destroy
    redirect_to writing_connect_url, notice: "Token revoked."
  end

  private
    def api_token_params
      params.require(:api_token).permit(:name)
    end
end
