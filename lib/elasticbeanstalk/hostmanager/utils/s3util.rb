#############################################################################
# AWS ElasticBeanstalk Host Manager
# Copyright 2011 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the “License”). You may
# not use this file except in compliance with the License. A copy of the
# License is located at
#
# http://aws.amazon.com/asl/
#
# or in the “license” file accompanying this file. This file is
# distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
# ANY KIND, express or implied. See the License for the specific
# language governing permissions and limitations under the License.
#

require 'net/https'
require 'uri'

module ElasticBeanstalk
  module HostManager
    module Utils

      class S3Util
        # only try twice
        @@max_attempts = 2
        
        # 5 second timeout for opening connection to S3
        @@open_timeout = 5
        
        # 5 min timeout for connection
        @@read_timeout = 300
        
        def self.put(url, data, headers={})
          raise "PUT requires data" if !data
          request(:put, url, data, headers)
        end
        
        def self.post(url, data, headers={})
          raise "POST requires data" if !data
          request(:post, url, data, headers)
        end
    
        def self.get(url)
          request(:get, url)
        end

        def self.request(verb, signed_url, data=nil, headers={})
          # Only accept pre-signed URLs
          validate_url(signed_url)
          
          # Parse the URL
          uri = URI.parse(signed_url)
          
          attempts = 0
                    
          begin
            # Always created a fresh connection
            http = create_connection(uri)

            attempts += 1

            # Perform the request and time it, return response and time
            request_blk = proc {
              req = create_request(verb, uri, data, headers)
              
              start_time = Time.now
              response = http.request(req)
              end_time = Time.now
              
              unless response.code == '200'
                msg = "Cannot #{verb} #{uri}.  Encountered HTTP error code #{response.code}."
                Event.store('S3Util', msg, :error, [ :s3 ])
                raise msg
              end

              { :response => response, :time => end_time - start_time }
            }
            
            # Open connection and send request
            http.start(&request_blk)
          rescue Errno::EPIPE, Timeout::Error, Errno::EINVAL, EOFError
            # Force conn close
            http.finish if http.started?
            
            # Retry if we haven't reached max attempts yet, otherwise
            # raise the exception again
            puts "S3 request error: #{$!} (Attempt #{attempts} of #{@@max_attempts}.)"
            attempts >= @@max_attempts ? raise : retry
          end
        end

        def self.create_url(location_info)

        end

        private

        # Ghetto pre-signed URL check        
        def self.validate_url(url)
          ##raise "A signed URL is required" if (!url || !url.include?('&Signature='))
          raise "A nonempty URL is required" if (!url || url.empty?)
        end
        
        def self.create_request(verb, uri, data=nil, headers={})
          req = Net::HTTP.const_get(verb.to_s.capitalize).new(uri.request_uri)

          if (data)
            # Reset the stream if applicable
            data.rewind if data.respond_to?(:rewind)
            
            # If a stream, set the body_stream
            if (data.respond_to?(:read))
              req.body_stream = data
            else
              req.body = data
            end
          
            # Set the content length
            req.content_length = 
              data.respond_to?(:lstat) ? data.stat.size : data.size
            
            headers.each do |k, v| 
             req[k]=v
            end
          end
            
          req
        end
        
        def self.create_connection(uri)
          http = Net::HTTP.new(uri.host, uri.port)
          
          # Don't verify certs
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          
          # Based on port, choose SSL or not
          http.use_ssl = (uri.port == 443)
          
          # Timeout
          http.open_timeout = @@open_timeout
          http.read_timeout = @@read_timeout
          
          http
        end
        
      end # LogPub class
      
    end # Tasks module
  end # HostManager module
end # ElasticBeanstalk module
