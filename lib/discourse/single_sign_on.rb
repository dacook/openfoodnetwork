# frozen_string_literal: true

# This class is the reference implementation of a SSO provider from Discourse.

module Discourse
  class SingleSignOn
    ACCESSORS = [:nonce, :name, :username, :email, :avatar_url, :avatar_force_update,
                 :require_activation, :about_me, :external_id, :return_sso_url, :admin, :moderator,
                 :suppress_welcome_message].freeze
    FIXNUMS = [].freeze
    BOOLS = [:avatar_force_update, :admin, :moderator, :require_activation,
             :suppress_welcome_message].freeze
    NONCE_EXPIRY_TIME = 10.minutes

    attr_accessor(*ACCESSORS, :sso_secret, :sso_url)

    def self.sso_secret
      raise "sso_secret not implemented on class, be sure to set it on instance"
    end

    def self.sso_url
      raise "sso_url not implemented on class, be sure to set it on instance"
    end

    def self.parse(payload, sso_secret = nil)
      sso = new
      sso.sso_secret = sso_secret if sso_secret

      parsed = Rack::Utils.parse_query(payload)
      if sso.sign(parsed["sso"]) != parsed["sig"]
        diags = "\n\nsso: #{parsed['sso']}\n\nsig: #{parsed['sig']}\n\n" \
                "expected sig: #{sso.sign(parsed['sso'])}"
        if parsed["sso"] =~ %r{[^a-zA-Z0-9=\r\n/+]}m
          raise "The SSO field should be Base64 encoded, using only A-Z, a-z, 0-9, +, /, " \
                "and = characters. Your input contains characters we don't understand as Base64, " \
                "see http://en.wikipedia.org/wiki/Base64 #{diags}"
        else
          raise "Bad signature for payload #{diags}"
        end
      end

      decoded = Base64.decode64(parsed["sso"])
      decoded_hash = Rack::Utils.parse_query(decoded)

      ACCESSORS.each do |k|
        val = decoded_hash[k.to_s]
        val = val.to_i if FIXNUMS.include? k
        if BOOLS.include? k
          val = ["true", "false"].include?(val) ? val == "true" : nil
        end
        sso.public_send("#{k}=", val)
      end

      decoded_hash.each do |k, v|
        # 1234567
        # custom.
        #
        if k[0..6] == "custom."
          field = k[7..-1]
          sso.custom_fields[field] = v
        end
      end

      sso
    end

    def sso_secret
      @sso_secret || self.class.sso_secret
    end

    def sso_url
      @sso_url || self.class.sso_url
    end

    def custom_fields
      @custom_fields ||= {}
    end

    def sign(payload)
      OpenSSL::HMAC.hexdigest("sha256", sso_secret, payload)
    end

    def to_url(base_url = nil)
      base = (base_url || sso_url).to_s
      "#{base}#{base.include?('?') ? '&' : '?'}#{payload}"
    end

    def payload
      payload = Base64.encode64(unsigned_payload)
      "sso=#{CGI.escape(payload)}&sig=#{sign(payload)}"
    end

    def unsigned_payload
      payload = {}
      ACCESSORS.each do |k|
        next if (val = public_send k).nil?

        payload[k] = val
      end

      @custom_fields&.each do |k, v|
        payload["custom.#{k}"] = v.to_s
      end

      Rack::Utils.build_query(payload)
    end
  end
end
