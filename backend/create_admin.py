#!/usr/bin/env python3
"""Create initial admin user."""
import sys
import getpass
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from main import Base, UserModel, hash_password

engine = create_engine(f"sqlite:///{Path(__file__).parent}/familyhub.db",
                       connect_args={"check_same_thread": False})
Base.metadata.create_all(bind=engine)
Session = sessionmaker(bind=engine)

def main():
    print("=" * 50)
    print("Family Hub - Admin User erstellen")
    print("=" * 50)
    username  = input("Username: ").strip()
    email     = input("Email: ").strip()
    full_name = input("Full Name (optional): ").strip()
    password  = getpass.getpass("Password: ")
    confirm   = getpass.getpass("Confirm Password: ")
    if password != confirm:
        print("Passwords do not match!"); sys.exit(1)
    if len(password) < 8:
        print("Password too short (min 8 chars)!"); sys.exit(1)

    with Session() as db:
        if db.query(UserModel).filter(UserModel.username == username).first():
            print(f"User '{username}' already exists!"); sys.exit(1)
        user = UserModel(
            username=username, email=email,
            full_name=full_name or username,
            hashed_pw=hash_password(password),
            is_admin=True,
        )
        db.add(user); db.commit()
    print("=" * 50)
    print(f"✓ Admin user '{username}' created!")
    print("=" * 50)

if __name__ == "__main__":
    main()
