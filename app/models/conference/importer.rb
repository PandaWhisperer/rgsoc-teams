require 'csv'
class Conference::Importer
  
  ## This importer is depending on agreed-upon input format.
  ## Input file:
  # - Dates should be formatted with dd mm yyyy
  # - UID should be unique and formatted with season + id: 2017001
  # - The headers should not be changed
  # Output:
  # - Conferences will be updated or created
  # - Conferences deleted in the input file, are not removed from the table
  # - Import errors are logged in a Rails Logger
  # - UID is mapped to 'gid' ('google-id' LOL), and has the format: 2017001
  
  class << self

    def call(file)
      check_valid(file)
      with_log(file) { process_csv(file) }
    end

    private

    def with_log(file)
      logger.tagged("Importer") { logger.info "Started importing file #{file.original_filename}" }
      yield
      logger.tagged("Importer") { logger.info "Finished updating/creating #{count_conferences_in(file)} conferences" }
    end

    def logger
      Rails.logger
    end
    
    def check_valid(file)
      raise ArgumentError, "Oops! I can upload .csv only :-(" unless file.content_type == "text/csv"
    end
    
    def count_conferences_in(file)
      CSV.foreach(file.path, headers: true).count
    end

    def fetch_season_id(uid)
      # uid format : 2017001
      year = uid.to_s[0,4]
      Season.find_or_create_by!(name: year).id
    end
    
    def process_csv(file)
      CSV.foreach(file.path, headers: true, col_sep: ';' ) do |row|
        begin
          conference = Conference.find_or_initialize_by(gid: row['UID'])
          conference_attributes = {
            name: row['Name'],
            starts_on: row['Start date'],
            ends_on: row['End date'],
            city: row['City'],
            country: row['Country'],
            region: row['Region'],
            url: row['Website'],
            notes: row['Notes'],
          }.merge(season_id: fetch_season_id(conference.gid))
          conference.update!(conference_attributes)
        rescue => e
          logger.tagged("Importer") { logger.error "Error in #{row['UID']}: #{e.message}" }
        end
      end
    end
  end
end
