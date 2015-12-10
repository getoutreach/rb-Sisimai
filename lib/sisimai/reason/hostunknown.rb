module Sisimai
  module Reason
    module HostUnknown
      # Imported from p5-Sisimail/lib/Sisimai/Reason/HostUnknown.pm
      class << self
        def text; return 'hostunknown'; end

        # Try to match that the given text and regular expressions
        # @param    [String] argv1  String to be matched with regular expressions
        # @return   [True,False]    false: Did not match
        #                           true: Matched
        def match(argv1)
          return nil unless argv1
          regex = %r{(?>
             domain[ ](?:
               does[ ]not[ ]exist
              |must[ ]exist
              |is[ ]not[ ]reachable
              )
            |host[ ](?:
               or[ ]domain[ ]name[ ]not[ ]found
              |unknown
              |unreachable
              )
            |name[ ]or[ ]service[ ]not[ ]known
            |no[ ]such[ ]domain
            |recipient[ ](?:
            address[ ]rejected:[ ]unknown[ ]domain[ ]name
              domain[ ]must[ ]exist
              )
            |unknown[ ]host
            )
          }ix

          return true if argv1 =~ regex
          return false
        end

        # Whether the host is unknown or not
        # @param    [Sisimai::Data] argvs   Object to be detected the reason
        # @return   [True,False]            true: is unknown host
        #                                   false: is not unknown host.
        # @see http://www.ietf.org/rfc/rfc2822.txt
        def true(argvs)
          return nil unless argvs
          return nil unless argvs.is_a? Sisimai::Data
          return true if argvs.reason == self.text

          require 'sisimai/smtp/status'
          statuscode = argvs.deliverystatus || ''
          reasontext = self.text
          tempreason = ''
          diagnostic = ''
          v = false

          tempreason = Sisimai::SMTP::Status.name(statuscode) if statuscode.size > 0
          diagnostic = argvs.diagnosticcode || ''

          if tempreason == reasontext
            # Status: 5.1.2
            # Diagnostic-Code: SMTP; 550 Host unknown
            v = true
          else
            # Check the value of Diagnosic-Code: header with patterns
            v = true if self.match(diagnostic)
          end
          return v
        end

      end
    end
  end
end


