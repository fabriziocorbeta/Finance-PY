class ArchivedExportsController < ApplicationController
  include ActiveStorage::Streaming

  skip_authentication

  def show
    export = ArchivedExport.find_by_download_token!(params[:token])

    if export.downloadable?
      send_blob_stream export.export_file.blob, disposition: "attachment"
    else
      head :gone
    end
  end
end
