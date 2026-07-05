class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :payouts, dependent: :destroy
  has_many :transactions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, format: { with: /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i }
end
