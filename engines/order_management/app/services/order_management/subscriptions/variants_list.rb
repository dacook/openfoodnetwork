# frozen_string_literal: false

module OrderManagement
  module Subscriptions
    class VariantsList
      # Includes the following variants:
      # - Variants of permitted producers
      # - Variants of hub
      # - Variants that are in outgoing exchanges where the hub is receiver
      def self.eligible_variants(distributor)
        # query = Spree::Variant.where(supplier: distributor).union(
        #   Spree::Variant.joins(supplier: :relationships_as_parent) #.merge(permitted_producer_scope(distributor))
        #                         .left_outer_joins(supplier: :relationships_as_parent)
        #                         .merge(EnterpriseRelationship.permitting(distributor.id).with_permission(:add_to_order_cycle))
        # )
        #
        query = Spree::Variant.joins( <<~SQL.squish
          INNER JOIN enterprises AS supplier
            ON spree_variants.supplier_id = supplier.id
          LEFT OUTER JOIN enterprise_relationships
            ON enterprise_relationships.parent_id = supplier.id
          INNER JOIN enterprise_relationship_permissions
            ON enterprise_relationship_permissions.enterprise_relationship_id = enterprise_relationships.id
          INNER JOIN enterprises AS permitted_enterprise
            ON enterprise_relationships.child_id = permitted_enterprise.id
        SQL
        ).where("
          spree_variants.deleted_at IS NULL
          AND (supplier_id = ?
           OR (enterprise_relationships.child_id = ?
             AND enterprise_relationship_permissions.name = 'add_to_order_cycle')
          )
        ", distributor.id, distributor.id)

        exchange_variant_ids = outgoing_exchange_variant_ids(distributor)
        if exchange_variant_ids.present?
          query = query.or(Spree::Variant.where(id: exchange_variant_ids))
        end

        query
      end

      def self.in_open_and_upcoming_order_cycles?(distributor, schedule, variant)
        scope = ExchangeVariant.joins(exchange: { order_cycle: :schedules })
          .where(variant_id: variant, exchanges: { incoming: false, receiver_id: distributor })
          .merge(OrderCycle.not_closed)
        scope = scope.where(schedules: { id: schedule })
        scope.any?
      end

      def self.permitted_producer_ids(distributor)
        self.permitted_producer_scope(distributor).pluck(:parent_id) | [distributor.id]
      end

      def self.permitted_producer_scope(distributor)
        EnterpriseRelationship.joins(:parent)
          .permitting(distributor.id).with_permission(:add_to_order_cycle)
          .merge(Enterprise.is_primary_producer)
      end

      def self.outgoing_exchange_variant_ids(distributor)
        ExchangeVariant.select("DISTINCT exchange_variants.variant_id").joins(:exchange)
          .where(exchanges: { incoming: false, receiver_id: distributor.id })
          .pluck(:variant_id)
      end
    end
  end
end
