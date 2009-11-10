#!/usr/bin/ruby

require 'rubygems'
require 'scrobbler'
require 'pp'

# http://www.last.fm/api/submissions
# http://scrobbler.rubyforge.org/docs/

#############################
# Configuration

# authentication file
AUTHFILE='authfile'

# poll interval
POLL_INTERVAL=1

# debug (don't do the actual scrobbling)
DEBUG = true

# log to file
# OUTPUT = 'mocp-scrobbler.log'
#############################

def log(str)
    if defined? OUTPUT
        @logfile.write(str+"\n")
    else
        puts str
    end
end

class Track
    attr_reader :file, :artist, :track, :album, :length, :track_number, :time, :currentsec, :submittable

    def initialize(track_hash)
        @file   = track_hash[:file]
        @artist = track_hash[:artist] || ''
        @track  = track_hash[:track] || ''
        @album  = track_hash[:album] || ''
        @length = track_hash[:length]
        @track_number = track_hash[:track_number] || '' 
        @time = Time.now
        @currentsec = track_hash[:currentsec]
    end

    def submittable?
        if !has_tags?
            log "#{@file} has no tags"
            return false
        end

        totalsec = @length.to_i
        currentsec = @currentsec.to_i

        log "TotalSec: #{totalsec.to_s}, CurrentSec: #{currentsec.to_s}, HalfSec: #{(totalsec/2).to_s}"

        if totalsec <= 30
            log "song shorter that 30s"
            return false
        end

        if currentsec >= 240 or currentsec >= totalsec/2
            return true
        else
            log "you have not reached 240s or half of the song"
            return false
        end
    end

    def has_tags?
        tags = [@artist, @album, @track]
        tags.each {|t| return false if t.empty? }
        true
    end

    def update_currentsec(track)
       @currentsec = track.currentsec 
    end

    def ==(track)
        @file == track.file
    end

    def display
        info = @file + "\n"
        info += "Artist: " + @artist + "\n"
        info += "Album: " + @album + "\n"
        info += "Track: " + @track + "\n"
        puts info
    end
end

module ScrobblerClient
    def initialize
        @config = get_config
        connect if !@config[:debug]
        @logfile = File.open(OUTPUT,'a') if @config[:output]
    end

    def get_config
        config = Hash.new
        config[:debug] = defined? DEBUG ? DEBUG : false
        config[:output] = defined? OUTPUT ? OUTPUT : false
        config[:poll_interval] = POLL_INTERVAL
        config[:authfile] = AUTHFILE
        config
    end
    
    
    def connect
        log "Connecting!"
        (login,password) = File.new(@config[:authfile]).readlines[0].chomp.split(':')
        @auth = Scrobbler::SimpleAuth.new(:user => login, :password => password)
        @auth.handshake!
    end

    def submit_now_playing(track)
        log "actually submitting the now_playing!"
        #playing = Scrobbler::Playing.new(:session_id => @auth.session_id,
        #                             :now_playing_url => @auth.now_playing_url,
        #                             :artist        => @fileinfo['Artist'],
        #                             :track         => @fileinfo['SongTitle'],
        #                             :album         => @fileinfo['Album'],
        #                             :length        => @fileinfo['TotalSec'],
        #                             :track_number  => '')
        #playing.submit!
    end

    def submit_scrobble(track)
        log "actually doing the scroblle!"
        #scrobble = Scrobbler::Scrobble.new(:session_id => @auth.session_id,
        #                               :submission_url => @auth.submission_url,
        #                               :artist        => @fileinfo['Artist'],
        #                               :track         => @fileinfo['SongTitle'],
        #                               :album         => @fileinfo['Album'],
        #                               :time          => @time_start,
        #                               :length        => @fileinfo['TotalSec'],
        #                               :track_number => '')
        #scrobble.submit!
    end


    def poll
        if server_running?
            track = get_track
            if !@currentTrack
                @currentTrack = track    

                if @currentTrack.has_tags?
                    log "updating now playing: #{@currentTrack.track}"
                    submit_now_playing if !@config[:debug] and 
                else
                    log "artist
                end
            else
                if @currentTrack == track
                    @currentTrack.update_currentsec(track)
                else
                    if @currentTrack.submittable?
                        log "scrobbling #{@currentTrack.track}"
                    end
                    @currentTrack = track
                    log "now playing #{@currentTrack.track}"
                end
            end
        else
           log "server stopped" 
        end
    end

end


class MocpScrobbler
    include ScrobblerClient

    def get_track
        fileinfo = Hash.new
        `mocp -i`.split("\n").each do |l| 
            (k,v) = l.split(': ')
            if v.class != String
                v = String.new
            end
            fileinfo[k.intern] = v.strip
        end

        track_hash = {
            :file => fileinfo[:File],
            :artist => fileinfo[:Artist],
            :track => fileinfo[:SongTitle],
            :album => fileinfo[:Album],
            :length => fileinfo[:TotalSec],
            :track_number => '',
            :currentsec => fileinfo[:CurrentSec]
         }

         Track.new(track_hash)
    end

    def server_running?
        state = `mocp -i`.split("\n").select{|el| el =~ /^State: /}.first.split(': ')[1]
        state != 'STOP'
    end
end

mocp = MocpScrobbler.new

while true
    mocp.poll
    sleep POLL_INTERVAL
end
