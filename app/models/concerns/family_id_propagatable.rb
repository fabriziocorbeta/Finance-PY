module FamilyIdPropagatable
  extend ActiveSupport::Concern

  class_methods do
    # "Push" direction: propagates this record's family_id onto an
    # association before that association validates/saves. Needed for
    # delegated_type parents (Entry -> entryable, Account -> accountable),
    # whose belongs_to autosave validates the child BEFORE the parent, so
    # the child's own family_id must already be set by then.
    #
    # `from` is either :family_id (this record's own column, e.g. Account)
    # or another association name whose .family_id is the real source
    # (e.g. Entry pushes via :account, since Entry itself has no family_id).
    #
    # Registered on both before_validation and before_save: a caller can
    # stub away #valid? entirely (bypassing the whole validation phase,
    # before_validation included), but before_save still fires regardless
    # of how validation was satisfied. Idempotent, safe to run twice.
    def propagates_family_id_to(association_name, from: :family_id)
      method_name = :"propagate_family_id_to_#{association_name}"

      define_method(method_name) do
        target = public_send(association_name)
        source_id = from == :family_id ? family_id : public_send(from)&.family_id
        target.family_id = source_id if target && source_id && target.respond_to?(:family_id=)
      end

      before_validation method_name, prepend: true
      before_save method_name, prepend: true
      private method_name
    end

    # "Pull" direction: the mirror case, for when THIS record is built as
    # the outer object (e.g. Transaction.new(entry: Entry.new(account: ...))
    # instead of Entry.new(entryable: Transaction.new)) -- the association
    # chain is already in memory here even though the associated record's
    # own push callback never ran, because this record is the one being
    # validated first in that direction.
    #
    # `chain` is a list of association names walked from self down to (but
    # not including) :family_id itself, e.g. pulls_family_id_from(:entry,
    # :account) reads entry&.account&.family_id. Uses ||= so an
    # explicitly-set family_id from the caller is preserved.
    def pulls_family_id_from(*chain)
      method_name = :"assign_family_from_#{chain.first}"

      define_method(method_name) do
        return unless respond_to?(:family_id=)
        target = chain.reduce(self) { |obj, meth| obj&.public_send(meth) }
        self.family_id ||= target&.family_id
      end

      before_validation method_name, prepend: true
      before_save method_name, prepend: true
    end
  end
end
