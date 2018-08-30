module Sisimai
  # Sisimai::MIME is MIME Utilities for Sisimai.
  module MIME
    # Imported from p5-Sisimail/lib/Sisimai/MIME.pm
    class << self
      require 'base64'
      require 'sisimai/string'

      ReE = {
        :'7bit-encoded' => %r/^content-transfer-encoding:[ ]*7bit$/m,
        :'quoted-print' => %r/^content-transfer-encoding:[ ]*quoted-printable$/m,
        :'some-iso2022' => %r/^content-type:[ ]*.+;[ ]*charset=["']?(iso-2022-[-a-z0-9]+?)['"]?$/m,
        :'with-charset' => %r/^content[-]type:[ ]*.+[;][ ]*charset=['"]?(.+?)['"]?$/,
        :'only-charset' => %r/^[\s\t]+charset=['"]?(.+?)['"]?$/,
        :'html-message' => %r|^content-type:[ ]*text/html;|m,
      }.freeze

      # Make MIME-Encoding and Content-Type related headers regurlar expression
      # @return   [Array] Regular expressions related to MIME encoding
      def patterns
        return ReE
      end

      # Check that the argument is MIME-Encoded string or not
      # @param    [String] argvs  String to be checked
      # @return   [True,False]    false: Not MIME encoded string
      #                           true:  MIME encoded string
      def is_mimeencoded(argv1)
        return false unless argv1

        argv1.delete!('"')
        piece = []
        mime1 = false

        if argv1.include?(' ')
          # Multiple MIME-Encoded strings in a line
          piece = argv1.split(' ')
        else
          piece << argv1
        end

        while e = piece.shift do
          # Check all the string in the array
          next unless e.match?(/[ \t]*=[?][-_0-9A-Za-z]+[?][BbQq][?].+[?]=?[ \t]*/)
          mime1 = true
        end
        return mime1
      end

      # Decode MIME-Encoded string
      # @param    [Array] argvs   An array including MIME-Encoded text
      # @return   [String]        MIME-Decoded text
      def mimedecode(argvs = [])
        characterset = nil
        encodingname = nil
        mimeencoded0 = nil
        decodedtext0 = []
        notmimetext0 = ''
        notmimetext1 = ''

        while e = argvs.shift do
          # Check and decode each element
          e = e.strip.delete('"')

          if self.is_mimeencoded(e)
            # MIME Encoded string
            if cv = e.match(/\A(.*)=[?]([-_0-9A-Za-z]+)[?]([BbQq])[?](.+)[?]=?(.*)\z/)
              # =?utf-8?B?55m954yr44Gr44KD44KT44GT?=
              notmimetext0   = cv[1]
              characterset ||= cv[2]
              encodingname ||= cv[3]
              mimeencoded0   = cv[4]
              notmimetext1   = cv[5]

              decodedtext0 << notmimetext0
              if encodingname == 'Q'
                # Quoted-Printable
                decodedtext0 << mimeencoded0.unpack('M').first

              elsif encodingname == 'B'
                # Base64
                decodedtext0 << Base64.decode64(mimeencoded0)
              end
              decodedtext0 << notmimetext1
            end
          else
            decodedtext0 << e
          end
        end

        return '' if decodedtext0.empty?
        decodedtext1 = decodedtext0.join('')

        if characterset && encodingname
          # utf8 => UTF-8
          characterset = 'UTF-8' if characterset.casecmp('UTF8') == 0

          unless characterset.casecmp('UTF-8') == 0
            # Characterset is not UTF-8
            begin
              decodedtext1.encode!('UTF-8', characterset)
            rescue
              decodedtext1 = 'FAILED TO CONVERT THE SUBJECT'
            end
          end
        end

        return decodedtext1.force_encoding('UTF-8')
      end

      # Decode MIME Quoted-Printable Encoded string
      # @param  [String] argv1   MIME Encoded text
      # @param  [Hash]   heads   Email header
      # @return [String]         MIME Decoded text
      def qprintd(argv1 = nil, heads = {})
        return nil unless argv1
        return argv1.unpack('M').first unless heads['content-type']
        return argv1.unpack('M').first if heads['content-type'].empty?

        # Quoted-printable encoded part is the part of the text
        boundary00 = Sisimai::MIME.boundary(heads['content-type'], 0)

        # Decoded using unpack('M') entire body string when the boundary string
        # or "Content-Transfer-Encoding: quoted-printable" are not included in
        # the message body.
        return argv1.unpack('M').first if boundary00.empty?
        return argv1.unpack('M').first unless argv1.downcase.match?(ReE[:'quoted-print'])

        boundary01 = Sisimai::MIME.boundary(heads['content-type'], 1)
        bodystring = ''
        notdecoded = ''
        getencoded = ''
        lowercased = ''

        encodename = nil
        ctencoding = nil
        mimeinside = false
        mustencode = false
        hasdivided = argv1.split("\n")

        while e = hasdivided.shift do
          # This is a multi-part message in MIME format. Your mail reader does not
          # understand MIME message format.
          # --=_gy7C4Gpes0RP4V5Bs9cK4o2Us2ZT57b-3OLnRN+4klS8dTmQ
          # Content-Type: text/plain; charset=iso-8859-15
          # Content-Transfer-Encoding: quoted-printable
          if mimeinside
            # Quoted-Printable encoded text block
            if e == boundary00
              # The next boundary string has appeared
              # --=_gy7C4Gpes0RP4V5Bs9cK4o2Us2ZT57b-3OLnRN+4klS8dTmQ
              getencoded = Sisimai::String.to_utf8(notdecoded.unpack('M').first, encodename)
              bodystring << getencoded << e + "\n"

              notdecoded = ''
              mimeinside = false
              ctencoding = false
              encodename = nil
            else
              # Inside of Quoted-Printable encoded text
              if e.size > 76
                # Invalid line exists in "quoted-printable" part
                e = [e].pack('M').chomp
              else
                # A bounce message generated by Office365(Outlook) include lines
                # which are not proper as Quoted-Printable:
                #   - `=` is not encoded
                #   - Longer than 76 charaters a line
                #
                # Content-Transfer-Encoding: quoted-printable
                # X-Microsoft-Exchange-Diagnostics:
                #     1;SLXP216MB0381;27:IdH7U/WHGgJu6J8lFrE7KvVxhnAwyKrNbSXMFYs3/Gzz6ZdXYYjzHj55K2O+cndpeVwkvBJqmo6y0IF4AhLfHtFzznw/BzhERU6wi/TCWRpyjYuW8v0/aTcflH3oAdgZ4Pwrp7PxLiiA8rYgU/E7SQ==
                # ...
                mustencode = true
                while true do
                  break if e.end_with?(' ', "\t")
                  break if e.split('').any? { |c| c.ord < 32 || c.ord > 126 }
                  if e.end_with?('=')
                    # Padding character of Base64 or not
                    break if e.match?(/[\+\/0-9A-Za-z]{32,}[=]+\z/)
                  else
                    if e.include?('=') && ! e.upcase.include?('=3D')
                      # Including "=" not as "=3D"
                      break
                    end
                  end
                  mustencode = false
                  break
                end
                e = [e].pack('M').chomp if mustencode
                mustencode = false
              end
              notdecoded << e + "\n"
            end
          else
            # NOT Quoted-Printable encoded text block
            lowercased = e.downcase
            if e.match?(/\A[-]{2}[^\s]+[^-]\z/)
              # Start of the boundary block
              # --=_gy7C4Gpes0RP4V5Bs9cK4o2Us2ZT57b-3OLnRN+4klS8dTmQ
              unless e == boundary00
                # New boundary string has appeared
                boundary00 = e
                boundary01 = e + '--'
              end
            elsif cv = lowercased.match(ReE[:'with-charset']) || lowercased.match(ReE[:'only-charset'])
              # Content-Type: text/plain; charset=ISO-2022-JP
              encodename = cv[1]
              mimeinside = true if ctencoding

            elsif lowercased.match?(ReE[:'quoted-print'])
              # Content-Transfer-Encoding: quoted-printable
              ctencoding = true
              mimeinside = true if encodename

            elsif e == boundary01
              # The end of boundary block
              # --=_gy7C4Gpes0RP4V5Bs9cK4o2Us2ZT57b-3OLnRN+4klS8dTmQ--
              mimeinside = false
            end

            bodystring << e + "\n"
          end
        end

        bodystring << notdecoded unless notdecoded.empty?
        return bodystring
      end

      # Decode MIME BASE64 Encoded string
      # @param  [String] argv1   MIME Encoded text
      # @return [String]         MIME-Decoded text
      def base64d(argv1)
        return nil unless argv1

        plain = nil
        if cv = argv1.match(%r|([+/\=0-9A-Za-z\r\n]+)|)
          # Decode BASE64
          plain = Base64.decode64(cv[1])
        end
        return plain.force_encoding('UTF-8')
      end

      # Get boundary string
      # @param    [String]  argv1 The value of Content-Type header
      # @param    [Integer] start -1: boundary string itself
      #                            0: Start of boundary
      #                            1: End of boundary
      # @return   [String] Boundary string
      def boundary(argv1 = nil, start = -1)
        return nil unless argv1
        value = ''

        if cv = argv1.match(/\bboundary=([^ ]+)/i)
          # Content-Type: multipart/mixed; boundary=Apple-Mail-5--931376066
          # Content-Type: multipart/report; report-type=delivery-status;
          #    boundary="n6H9lKZh014511.1247824040/mx.example.jp"
          value = cv[1]
          value.delete!(%q|'"|)
          value = '--' + value if start > -1
          value = value + '--' if start >  0
        end

        return value
      end
    end

  end
end

