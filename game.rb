#encoding: utf-8

require "bundler/setup"
require "gaminator"

class Array
  def x
    self.first
  end

  def y
    self.last
  end
end

class BindingGame
  MOVE = {
    :up => [0, -1],
    :down => [0, 1],
    :left => [-2, 0],
    :right => [2, 0]
  }

  module Coordinates
    def coordinates
      [x, y]
    end

    def desired_coordinates(x, y)
      [self.x + x, self.y + y]
    end

    def move(x, y)
      self.x += x
      self.y += y
    end
  end

  class Wall < Struct.new(:x, :y)
    include Coordinates

    def char
      '#'
    end
  end

  class Bullet < Struct.new(:x, :y)
    include Coordinates

    attr_accessor :type, :vector

    def initialize(type, vec, x, y)
      self.type  = type
      self.vector = vec
      super(x, y)
    end

    def char
      '*'
    end

    def color
      player? ? Curses::COLOR_GREEN : Curses::COLOR_RED
    end

    def player?
      type == :player
    end

    def move
      self.x += vector.x
      self.y += vector.y
    end
  end

  class Ascii < Struct.new(:x, :y)
    include Coordinates

    def char
      '@'
    end

    def color
      Curses::COLOR_BLUE
    end
  end

  class Enemy < Struct.new(:x, :y)
    include Coordinates

    attr_accessor :tick, :last_shot

    def initialize(x, y, tick = 0)
      self.tick = tick
      self.last_shot = rand(10)
      super(x, y)
    end

    def tick_me
      self.tick += 1
      self.last_shot += 1
    end

    def char
      '&'
    end

    def shoot
      self.last_shot = rand(10)
    end
  end

  def initialize(width, height)
    @bullets  = []
    @width    = width
    @height   = height
    @ascii    = Ascii.new(4, 4)
    @tick     = 0
    @walls    = []
    @cwalls   = []
    @enemies  = []
    initialize_walls
  end

  MOVE.each do |dir, vec|
    define_method "move_#{dir}" do
      unless @cwalls.include? @ascii.desired_coordinates(vec.x, vec.y)
        @ascii.move(vec.x, vec.y)
      end
    end

    define_method "shoot_#{dir}" do
      @bullets << Bullet.new(:player, vec, @ascii.x, @ascii.y)
    end
  end

  def initialize_walls
    wp = @width%2 == 0 ? 2 : 1
    (@width - wp + 1).times do |x|
      @walls << Wall.new(x, 0)
      @walls << Wall.new(x, @height-1)
    end
    @height.times do |y|
      @walls << Wall.new(0, y)
      @walls << Wall.new(@width-wp, y)
    end

    40.times do |i|
      @walls << Wall.new(10+i,7)
    end

    40.times do |i|
      @walls << Wall.new(30+i,14)
    end

    20.times do |i|
      @walls << Wall.new(26,10+i)
    end

    20.times do |i|
      @walls << Wall.new(52,i+i)
    end
  end

  def check_bullet_collisions
    check_wall_collisions
    check_enemies_collisions
    check_player_collisions
  end

  def check_wall_collisions
    to_remove =[]
    @bullets.each_with_index do |bullet, i|
      to_remove << i if @cwalls.include? bullet.coordinates
    end
    to_remove.reverse.each { |i| @bullets.delete_at(i) }
  end

  def check_enemies_collisions
    @bullets.delete_if do |bullet|
      !!@enemies.reject!{ |enemy| enemy.coordinates == bullet.coordinates && bullet.player? }
    end
  end

  def check_player_collisions
    @bullets.each do |bullet|
      if @ascii.coordinates == bullet.coordinates
        @status = "You are dead! You lasted #{(@tick * sleep_time).round(2)} seconds"
        exit
      end
    end
  end

  def move_enemies
    @enemies.each do |enemy|
      try_to_shoot(enemy)
      enemy.tick_me
      if enemy.tick%7 == 0
        vec = MOVE[MOVE.keys.sample]
        enemy.move(vec.x, vec.y) unless @cwalls.include? enemy.desired_coordinates(vec.x, vec.y)
      end
      try_to_shoot(enemy)
    end
  end

  def try_to_shoot(enemy)
    if enemy.last_shot > 20
      if enemy.x == @ascii.x
        @bullets << Bullet.new(:enemy, MOVE[ enemy.y - @ascii.y > 0 ? :up : :down ], enemy.x, enemy.y)
        enemy.shoot
      elsif enemy.y == @ascii.y
        @bullets << Bullet.new(:enemy, MOVE[ enemy.x - @ascii.x > 0 ? :left : :right ], enemy.x, enemy.y)
        enemy.shoot
      end
    end
  end

  def spawn_new_enemies
    if @tick%30 == 0
      @enemies << Enemy.new(rand((@width-2)/2+1)*2, rand(@height-3)+1)
    end
  end

  def tick
    @cwalls = @walls.map(&:coordinates)
    move_bullets
    check_bullet_collisions
    move_enemies
    spawn_new_enemies
    @tick += 1
  end

  def exit
    @status ||= "Bye bye! See ya later!"
    Kernel.exit
  end

  def exit_message
    @status
  end

  def objects
    [@ascii] + @walls + @bullets + @enemies
  end

  def input_map
    {
      "a" => :move_left,
      "d" => :move_right,
      "w" => :move_up,
      "s" => :move_down,
      "k" => :shoot_up,
      "j" => :shoot_down,
      "h" => :shoot_left,
      "l" => :shoot_right,
      "q" => :exit
    }
  end

  def move_bullets
    @bullets.each(&:move)
  end

  def textbox_content
    "w, s, a, d for move. h, j, k ,l for shoot. Fight if you can!"
  end

  def wait?
    false
  end

  def sleep_time
    0.05
  end
end

Gaminator::Runner.new(BindingGame).run
