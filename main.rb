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

        log "Listening to #{@file}"
    end

    def submittable?
        if !has_tags
            log "#{@file} has no tags"
            return false
        end

        totalsec = @totalsec.to_i
        currentsec = @currentsec.to_i

        if totalsec <= 30
            log "song shorter that 30s"
            return false
        end

        if currentsec >= 240 or currentsec >= totalsec/2
            return true
        else
            log "you have not reaced 240s or half of the song"
            return false
        end
    end

    def update_currentsec(currentsec)
       @currentsec = currentsec 
       log "CurrentSec: #{@currentsec}, TotalSec: #{@length}"
    end

    def ==(file)
        @file == file
    end

    def to_s
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
        playing = Scrobbler::Playing.new(:session_id => @auth.session_id,
                                     :now_playing_url => @auth.now_playing_url,
                                     :artist        => @fileinfo['Artist'],
                                     :track         => @fileinfo['SongTitle'],
                                     :album         => @fileinfo['Album'],
                                     :length        => @fileinfo['TotalSec'],
                                     :track_number  => '')

        playing.submit!
    end

    def submit_scrobble(track)
        scrobble = Scrobbler::Scrobble.new(:session_id => @auth.session_id,
                                       :submission_url => @auth.submission_url,
                                       :artist        => @fileinfo['Artist'],
                                       :track         => @fileinfo['SongTitle'],
                                       :album         => @fileinfo['Album'],
                                       :time          => @time_start,
                                       :length        => @fileinfo['TotalSec'],
                                       :track_number => '')
        scrobble.submit!
    end


    def poll
        
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
end

mocp = MocpScrobbler.new

while true
    pp mocp.get_track
    sleep POLL_INTERVAL
end
