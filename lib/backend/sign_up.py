import bcrypt
from flask import Flask, request, jsonify
from flask import Response
from flask_cors import CORS
from pymongo import MongoClient
from bson.objectid import ObjectId
import os
from dotenv import load_dotenv
import random
import cv2
import threading
import time
import numpy as np
from datetime import datetime
import platform

load_dotenv()

Mongo_URL = os.getenv('Mongo_URL')
app = Flask(__name__)
CORS(app)

client = MongoClient(Mongo_URL)
db = client["Test_1"]
users_collection = db["user"]
location_collection = db["location"]
cameras_collection = db["cameras"]
detection_logs_collection = db["detection_logs"]

AVAILABLE_COLORS = [
    "#4285F4",  # Blue
    "#DB4437",  # Red
    "#F4B400",  # Yellow
    "#0F9D58",  # Green
    "#AB47BC",  # Purple
]

def get_random_color():
    return random.choice(AVAILABLE_COLORS)

# ===== Camera Management System =====
class CameraManager:
    def __init__(self):
        self.cameras = {}
        self.active_streams = {}
        self.detection_results = {}
        self.lock = threading.Lock()
        
    def detect_cameras(self):
        """ตรวจจับกล้องที่เชื่อมต่ออยู่"""
        cameras = []
        
        if platform.system() == "Windows":
            # สำหรับ Windows
            for i in range(10):  # ตรวจสอบ 10 ช่องแรก
                cap = cv2.VideoCapture(i)
                if cap.isOpened():
                    ret, frame = cap.read()
                    if ret:
                        cameras.append({
                            'id': i,
                            'name': f'Camera {i}',
                            'device_path': f'/dev/video{i}',
                            'is_active': True
                        })
                    cap.release()
        else:
            # สำหรับ Linux/Mac
            for i in range(10):
                cap = cv2.VideoCapture(i)
                if cap.isOpened():
                    ret, frame = cap.read()
                    if ret:
                        cameras.append({
                            'id': i,
                            'name': f'Camera {i}',
                            'device_path': f'/dev/video{i}',
                            'is_active': True
                        })
                    cap.release()
        
        with self.lock:
            self.cameras = {cam['id']: cam for cam in cameras}
        
        return cameras
    
    def start_camera_stream(self, camera_id):
        """เริ่ม stream กล้อง"""
        if camera_id in self.active_streams:
            return True
            
        cap = cv2.VideoCapture(camera_id)
        if not cap.isOpened():
            return False
            
        # ตั้งค่าความละเอียด
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        cap.set(cv2.CAP_PROP_FPS, 30)
        
        with self.lock:
            self.active_streams[camera_id] = cap
            self.detection_results[camera_id] = []
        
        return True
    
    def stop_camera_stream(self, camera_id):
        """หยุด stream กล้อง"""
        with self.lock:
            if camera_id in self.active_streams:
                self.active_streams[camera_id].release()
                del self.active_streams[camera_id]
            if camera_id in self.detection_results:
                del self.detection_results[camera_id]
    
    def stop_all_streams(self):
        """หยุด stream ทุกตัว"""
        with self.lock:
            for cap in self.active_streams.values():
                cap.release()
            self.active_streams.clear()
            self.detection_results.clear()
    
    def get_frame(self, camera_id):
        """ดึงเฟรมจากกล้อง"""
        with self.lock:
            if camera_id not in self.active_streams:
                return None
                
            cap = self.active_streams[camera_id]
            ret, frame = cap.read()
            
            if not ret:
                return None
            
            # Encode เป็น JPEG
            _, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
            return buffer.tobytes()
    
    def perform_detection(self, camera_id):
        """ทำการตรวจจับบนเฟรมปัจจุบัน"""
        with self.lock:
            if camera_id not in self.active_streams:
                return []
                
            cap = self.active_streams[camera_id]
            ret, frame = cap.read()
            
            if not ret:
                return []
        
        # ตัวอย่างการตรวจจับ (ใช้ mock data)
        # ในการใช้งานจริงจะใช้ YOLO หรือ model อื่นๆ
        detections = self._mock_detection(frame)
        
        with self.lock:
            self.detection_results[camera_id] = detections
        
        # บันทึกผลการตรวจจับลง database
        if detections:
            self._save_detection_logs(camera_id, detections)
        
        return detections
    
    def _mock_detection(self, frame):
        """Mock detection สำหรับทดสอบ"""
        detections = []
        
        # สุ่มการตรวจจับ
        if random.random() > 0.7:  # 30% โอกาสที่จะตรวจพบ
            num_detections = random.randint(1, 3)
            
            for _ in range(num_detections):
                detection = {
                    'class_name': random.choice(['license_plate', 'sticker', 'vehicle']),
                    'confidence': random.uniform(0.7, 0.95),
                    'bounding_box': {
                        'x': random.uniform(0.1, 0.6),
                        'y': random.uniform(0.1, 0.6),
                        'width': random.uniform(0.1, 0.3),
                        'height': random.uniform(0.1, 0.3)
                    },
                    'timestamp': datetime.now().isoformat()
                }
                detections.append(detection)
        
        return detections
    
    def _save_detection_logs(self, camera_id, detections):
        """บันทึกผลการตรวจจับลง database"""
        try:
            for detection in detections:
                log_entry = {
                    'camera_id': camera_id,
                    'class_name': detection['class_name'],
                    'confidence': detection['confidence'],
                    'bounding_box': detection['bounding_box'],
                    'timestamp': datetime.now(),
                    'created_at': datetime.now()
                }
                detection_logs_collection.insert_one(log_entry)
        except Exception as e:
            print(f"Error saving detection logs: {e}")

# สร้าง instance ของ CameraManager
camera_manager = CameraManager()

# สมัคร
@app.route("/signup", methods=["POST"])
def signup():
    data = request.json
    username = data.get("username")
    email = data.get("email")
    password = data.get("password")

    if users_collection.find_one({"email": email}):
        return jsonify({"message": "Email already exists"}), 400

    hashed_password = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())

    users_collection.insert_one({
        "username": username,
        "email": email,
        "password": hashed_password.decode('utf-8'),
        "color": get_random_color()
    })

    return jsonify({"message": "User registered successfully"}), 201

# เข้าสู่ระบบ
@app.route("/login", methods=["POST"])
def login():
    data = request.json
    input_value = data.get("input")  
    password = data.get("password")

    user = users_collection.find_one({
        "$or": [
            {"email": input_value},
            {"username": input_value}
        ]
    })

    if not user:
        return jsonify({"message": "User not found"}), 401

    if bcrypt.checkpw(password.encode('utf-8'), user["password"].encode('utf-8')):
        return jsonify({
            "username": user["username"],
            "email": user["email"],
            "color": user["color"]
        }), 200
    else:
        return jsonify({"message": "Incorrect password"}), 401

# ดึงข้อมูลผู้ใช้
@app.route("/get_user", methods=["POST"])
def get_user():
    data = request.json
    email = data.get("email")

    user = users_collection.find_one({"email": email})
    if not user:
        return jsonify({"message": "User not found"}), 404

    return jsonify({
        "username": user.get("username"),
        "email": user.get("email"),
        "color": user.get("color")
    }), 200

# ดึงข้อมูลสถานที่
@app.route('/locations', methods=['GET'])
def get_locations():
    user_email = request.args.get('user')

    if not user_email:
        return jsonify({"error": "Missing 'user' query parameter"}), 400

    query = {
        "$or": [
            {"owner_email": user_email},
            {"shared_with": {"$elemMatch": {"email": user_email}}}
        ]
    }

    locations = list(location_collection.find(query))

    for loc in locations:
        loc["_id"] = str(loc["_id"])

    return jsonify(locations)

# บันทึกข้อมูลสถานที่
@app.route('/save_locations', methods=['POST'])
def add_location():
    data = request.json
    name = data.get('name')
    address = data.get('address')
    color = data.get('color')
    description = data.get('description')
    owner_email = data.get('owner_email')
    shared_with = data.get('shared_with', [])

    new_location = {
        "name": name,
        "address": address,
        "color": color,
        "description": description,
        "owner_email": owner_email,
        "shared_with": shared_with
    }

    result = location_collection.insert_one(new_location)
    new_location["_id"] = str(result.inserted_id)

    return jsonify(new_location), 201


# ===== Camera API Endpoints =====

@app.route('/api/cameras/list', methods=['GET'])
def get_cameras():
    """ดึงรายการกล้องที่มีอยู่"""
    try:
        cameras = camera_manager.detect_cameras()
        return jsonify({
            'success': True,
            'cameras': cameras,
            'count': len(cameras)
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/cameras/<int:camera_id>/start', methods=['POST'])
def start_camera(camera_id):
    """เริ่ม stream กล้อง"""
    try:
        success = camera_manager.start_camera_stream(camera_id)
        if success:
            return jsonify({
                'success': True,
                'message': f'Camera {camera_id} started'
            })
        else:
            return jsonify({
                'success': False,
                'error': f'Failed to start camera {camera_id}'
            }), 400
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/cameras/<int:camera_id>/stop', methods=['POST'])
def stop_camera(camera_id):
    """หยุด stream กล้อง"""
    try:
        camera_manager.stop_camera_stream(camera_id)
        return jsonify({
            'success': True,
            'message': f'Camera {camera_id} stopped'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/cameras/stop_all', methods=['POST'])
def stop_all_cameras():
    """หยุด stream ทุกตัว"""
    try:
        camera_manager.stop_all_streams()
        return jsonify({
            'success': True,
            'message': 'All cameras stopped'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/cameras/<int:camera_id>/frame', methods=['GET'])
def get_camera_frame(camera_id):
    """ดึงเฟรมจากกล้อง"""
    try:
        frame_data = camera_manager.get_frame(camera_id)
        if frame_data:
            return Response(
                frame_data,
                mimetype='image/jpeg',
                headers={'Cache-Control': 'no-cache, no-store, must-revalidate'}
            )
        else:
            return jsonify({
                'success': False,
                'error': f'No frame available from camera {camera_id}'
            }), 404
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/detection/<int:camera_id>/detect', methods=['GET'])
def detect_objects(camera_id):
    """ทำการตรวจจับบนกล้อง"""
    try:
        detections = camera_manager.perform_detection(camera_id)
        return jsonify({
            'success': True,
            'camera_id': camera_id,
            'detections': detections,
            'count': len(detections),
            'timestamp': datetime.now().isoformat()
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/cameras/status', methods=['GET'])
def get_camera_status():
    """ดึงสถานะของระบบกล้อง"""
    try:
        with camera_manager.lock:
            active_cameras = list(camera_manager.active_streams.keys())
            total_detections = sum(
                len(detections) for detections in camera_manager.detection_results.values()
            )
        
        return jsonify({
            'success': True,
            'status': {
                'total_cameras': len(camera_manager.cameras),
                'active_cameras': len(active_cameras),
                'active_camera_ids': active_cameras,
                'total_detections': total_detections,
                'timestamp': datetime.now().isoformat()
            }
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/detection/logs', methods=['GET'])
def get_detection_logs():
    """ดึงประวัติการตรวจจับ"""
    try:
        # ดึงข้อมูล 100 รายการล่าสุด
        logs = list(detection_logs_collection.find().sort('timestamp', -1).limit(100))
        
        # แปลง ObjectId เป็น string
        for log in logs:
            log['_id'] = str(log['_id'])
            if 'timestamp' in log:
                log['timestamp'] = log['timestamp'].isoformat()
            if 'created_at' in log:
                log['created_at'] = log['created_at'].isoformat()
        
        return jsonify({
            'success': True,
            'logs': logs,
            'count': len(logs)
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

if __name__ == "__main__":
    print("🚀 Starting Flask Server with Camera Support...")
    print("📷 Detecting available cameras...")
    
    # ตรวจจับกล้องเมื่อเริ่มต้น
    try:
        cameras = camera_manager.detect_cameras()
        print(f"✅ Found {len(cameras)} camera(s)")
        
        for camera in cameras:
            print(f"   - Camera {camera['id']}: {camera['name']}")
    except Exception as e:
        print(f"⚠️  Camera detection error: {e}")
    
    print("\n🌐 Server running on http://127.0.0.1:5000")
    print("📡 Available Endpoints:")
    print("   User Management:")
    print("   - POST /signup")
    print("   - POST /login")
    print("   - POST /get_user")
    print("   - GET  /locations")
    print("   - POST /save_locations")
    print("   Camera System:")
    print("   - GET  /api/cameras/list")
    print("   - POST /api/cameras/<id>/start")
    print("   - POST /api/cameras/<id>/stop")
    print("   - GET  /api/cameras/<id>/frame")
    print("   - GET  /api/detection/<id>/detect")
    print("   - GET  /api/cameras/status")
    print("   - GET  /api/detection/logs")
    
    app.run(debug=True, port=5000)