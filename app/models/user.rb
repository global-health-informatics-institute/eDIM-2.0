require 'digest/sha1'
require 'digest/sha2'

class User < ActiveRecord::Base

  #establish_connection :billing_import
  self.table_name = "users"
  self.primary_key = "user_id"

  #include Openmrs

  validates :username, presence: true, uniqueness: true, length: { minimum: 5 }
  validates :password, presence: true, length: { minimum: 6 }

  #before_create :before_create
  before_save :encrypt_password

  cattr_accessor :current

  belongs_to :person, -> {where voided: false}, :foreign_key => :person_id
  has_many :user_properties, :foreign_key => :user_id
  has_many :user_roles, :foreign_key => :user_id
  has_many :names,-> { where "voided =  false"}, :class_name => 'PersonName', :foreign_key => :person_id

  def self.get_similar_user(username)
    users = User.where("username LIKE ?", "%#{username}%")
    return users
  end

  def first_name
    self.person.names.last.given_name rescue ''
  end

  def last_name
    self.person.names.last.family_name rescue ''
  end

  def display_name
    name = self.person.names.last

    return "#{name.given_name} #{name.family_name}".titleize
  end

  def fullname
    display_name
  end

  def language

  end

  def self.random_string(len)
    #generate a random password consisting of strings and digits
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    newpass = ""
    1.upto(len) { |i| newpass << chars[rand(chars.size-1)] }
    return newpass
  end

  def encrypt_password
    if salt.blank?
      self.salt = User.random_string(10)
      self.password = encrypt(self.password, self.salt)
    end
  end

  def encrypt(password,salt)
    Digest::SHA1.hexdigest(password+salt)
  end

  def self.authenticate(username, password)
    user = User.where(username: username).first
    if !user.blank?
      user.valid_password?(password) ? user : nil
    end
  end
  def password
    # We expect that the default OpenMRS interface is used to create users
    #self.password = encrypt(self.plain_password, self.salt) if self.plain_password

    self[:password]
  end

  def password_digest(pwd)
    encrypt(pwd, salt)
  end

  def encrypted_password
    self.password
  end


  def valid_password?(password)
    return false if encrypted_password.blank?
    is_valid = Digest::SHA1.hexdigest("#{password}#{salt}") == encrypted_password	|| encrypt(password, salt) == encrypted_password || Digest::SHA512.hexdigest("#{password}#{salt}") == encrypted_password
  end

  def role
    self.user_roles.last.role rescue ''
  end

  def self.current
    Thread.current[:user]
  end

  def self.current=(user)
    Thread.current[:user] = user
  end

end