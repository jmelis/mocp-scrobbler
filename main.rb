#!/usr/bin/ruby

require 'rubygems'
require 'scrobbler'

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
#############################

class MocpScrobbler
    attr_reader :fileinfo

    def initialize
        connect if !defined? DEBUG
    end

    def connect
        (login,password) = File.new(AUTHFILE).readlines[0].chomp.split(':')
        @auth = Scrobbler::SimpleAuth.new(:user => login, :password => password)
        @auth.handshake!
    end

    def get_fileinfo
        fileinfo = Hash.new
        `mocp -i`.split("\n").each{|l| (k,v) = l.split(': '); fileinfo[k] = v}
        fileinfo
    end

    def poll
        fileinfo_poll = get_fileinfo

        if fileinfo_poll['State'] != 'STOP'
            # If we have just started @fileinfo should be empty
            if !@fileinfo
                # now playing submission
                @fileinfo = fileinfo_poll
                puts "now playing: " + @fileinfo['SongTitle']
                @time_start = Time.now
                submit_now_playing if !defined? DEBUG
            else
                if changed(fileinfo_poll)
                    if submit_allowed
                        submit_scrobble if !defined? DEBUG
                        puts "scrobble: " + @fileinfo['SongTitle']
                    end
                    @time_start = Time.now
                    @fileinfo = fileinfo_poll
                    puts "now playing: " + @fileinfo['SongTitle']
                    submit_now_playing if !defined? DEBUG
                else
                    @fileinfo = fileinfo_poll
                end
            end
        else
            puts "server status STOP"
        end
    end


    def changed(fileinfo_poll)
        fileinfo_poll['File'] != @fileinfo['File']
    end

    def submit_allowed
        totalsec = @fileinfo['TotalSec'].to_i
        currentsec = @fileinfo['CurrentSec'].to_i
        halfsec = totalsec/2

        puts "TotalSec: #{totalsec.to_s}, CurrentSec: #{currentsec.to_s}, HalfSec: #{halfsec.to_s}"
        if totalsec <= 30
            puts "song shorter that 30s"
            puts "no scrobbling allowed"
            return false
        end
        if currentsec >= 240 or currentsec >= totalsec/2
            return true
        else
            puts "no scrobbling allowed"
            return false
        end
    end

    def submit_now_playing
        playing = Scrobbler::Playing.new(:session_id => @auth.session_id,
                                     :now_playing_url => @auth.now_playing_url,
                                     :artist        => @fileinfo['Artist'],
                                     :track         => @fileinfo['SongTitle'],
                                     :album         => @fileinfo['Album'],
                                     :length        => @fileinfo['TotalSec'],
                                     :track_number  => '')

        playing.submit!
    end

    def submit_scrobble
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
end

mocp = MocpScrobbler.new

while true
    mocp.poll
    sleep POLL_INTERVAL
end

