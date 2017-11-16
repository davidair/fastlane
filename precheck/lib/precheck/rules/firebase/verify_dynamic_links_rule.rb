require 'precheck/rule'
require 'xcodeproj'

module Precheck
  class VerifyFirebaseDynamicLinksRule < URLRule
    @@details_message = "Please see https://firebase.google.com/docs/dynamic-links/ios/create for details."

    def self.key
      :verify_firebase_dynamic_links
    end

    def self.env_name
      "VERIFY_FIREBASE_DYNAMIC_LINKS"
    end

    def self.friendly_name
      "Firebase Dynamic Links are valid or not in use"
    end

    def self.description
      "Checks if Firebase Dynamic Links are properly configured"
    end

    def check_item(item)
      perform_check(item: item)
    end

    def rule_block
      return lambda { |xcode_project_item|

        google_service_plist = xcode_project_item.get_google_service_plist()

        # Cannot check Dynamic Links if plist is missing
        if google_service_plist.nil?
          return RuleReturn.new(validation_state: VALIDATION_STATES[:passed])
        end

        podfile = xcode_project_item.get_podfile()
        # Cannot check Dynamic Links if Podfile is missing
        if podfile.nil?
          return RuleReturn.new(validation_state: VALIDATION_STATES[:passed])
        end

        dependency = podfile.dependencies.detect { |dep| dep.name == 'Firebase/DynamicLinks' || dep.name == 'Firebase/Invites' }

        # We need an Dynamic Link or Invites dependency to proceed
        if dependency.nil?
          return RuleReturn.new(validation_state: VALIDATION_STATES[:passed])
        end

        entitlements = xcode_project_item.get_entitlements()
        if entitlements.nil?
          return RuleReturn.new(validation_state: Precheck::VALIDATION_STATES[:failed], failure_data: "Your project is using Firebase Dynamic Links but you are missing the entitlements file. #{@@details_message}")
        end

        associated_domains = entitlements["com.apple.developer.associated-domains"]
        if associated_domains.nil? or associated_domains.length == 0
          return RuleReturn.new(validation_state: Precheck::VALIDATION_STATES[:failed], failure_data: "Your project is using Firebase Dynamic Links but your entitlements file does not specify any associated domains. #{@@details_message}")
        end

        has_app_links = false

        associated_domains.each do |associated_domain|
          # Note: ideally, we would check if the project specific prefix matches, but we don't currently have a way of getting it.
          # If it becomes available in GoogleService-Info.plist, we should do an exact string match here.
          if associated_domain.start_with?("applinks:") and associated_domain.end_with?("app.goo.gl")
            has_app_links = true
          end
        end

        return RuleReturn.new(validation_state: Precheck::VALIDATION_STATES[:failed], failure_data: "Your project is using is using Firebase Dynamic Links but none of the associated domains specifies an applink pointing to *.app.goo.gl. #{@@details_message}") unless has_app_links

        return RuleReturn.new(validation_state: VALIDATION_STATES[:passed])
      }
    end
  end
end
