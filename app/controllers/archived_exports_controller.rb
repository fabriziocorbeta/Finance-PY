class ArchivedExportsController < ApplicationController
  skip_authentication

  def show
    export = ArchivedExport.find_by_download_token!(params[:token])

    if export.downloadable?
      blob = export.export_file.blob
      send_data blob.download,
                filename: blob.filename.to_s,
                type: blob.content_type,
                disposition: "attachment"
    else
      head :gone
    end
  end
end
