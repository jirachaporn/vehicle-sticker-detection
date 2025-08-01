from flask import Flask, request, jsonify, Response
from flask_cors import CORS
from pymongo import MongoClient
from bson.objectid import ObjectId
from dotenv import load_dotenv
import random, cv2, os, bcrypt
import threading
import time

load_dotenv()

Mongo_URL = os.getenv('Mongo_URL')
app = Flask(__name__)
CORS(app)

client = MongoClient(Mongo_URL)
db = client["Test_1"]
users_collection = db["user"]
location_collection = db["location"]

# เก็บ camera streams และ locks
camera_streams = {}
camera_locks = {}

AVAILABLE_COLORS = [
    "#4285F4", "#DB4437", "#F4B400", "#0F9D58", "#AB47BC"
]

def get_random_color():
    return random.choice(AVAILABLE_COLORS)

# ฟังก์ชันสำหรับทดสอบกล้อง
def test_camera(camera_id, backend=cv2.CAP_ANY):
    """ทดสอบว่ากล้องสามารถเปิดและอ่านเฟรมได้หรือไม่"""
    try:
        cap = cv2.VideoCapture(camera_id, backend)
        if cap.isOpened():
            # ตั้งค่า resolution ให้เล็กลงเพื่อประสิทธิภาพที่ดีขึ้น
            cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
            cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
            cap.set(cv2.CAP_PROP_FPS, 15)
            
            # ทดสอบอ่านเฟรม
            ret, frame = cap.read()
            cap.release()
            return ret and frame is not None
        return False
    except Exception as e:
        print(f"Error testing camera {camera_id}: {e}")
        return False

# -------------------- USER SYSTEM --------------------

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

@app.route("/login", methods=["POST"])
def login():
    data = request.json
    input_value = data.get("input")
    password = data.get("password")

    user = users_collection.find_one({
        "$or": [{"email": input_value}, {"username": input_value}]
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

# -------------------- LOCATION SYSTEM --------------------

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

@app.route('/save_locations', methods=['POST'])
def add_location():
    data = request.json
    new_location = {
        "name": data.get('name'),
        "address": data.get('address'),
        "color": data.get('color'),
        "description": data.get('description'),
        "owner_email": data.get('owner_email'),
        "shared_with": data.get('shared_with', [])
    }

    result = location_collection.insert_one(new_location)
    new_location["_id"] = str(result.inserted_id)
    return jsonify(new_location), 201

# # -------------------- CAMERA STREAMING --------------------

# @app.route('/api/cameras/list', methods=['GET'])
# def list_available_cameras():
#     print("Scanning for available cameras...")
#     available = []
    
#     # ลอง backends ต่างๆ
#     backends = [cv2.CAP_DSHOW, cv2.CAP_MSMF, cv2.CAP_ANY]
    
#     for camera_id in range(10):  # ตรวจสอบกล้อง 0-9
#         camera_found = False
        
#         for backend in backends:
#             if test_camera(camera_id, backend):
#                 available.append({
#                     "id": camera_id, 
#                     "name": f"Camera {camera_id}",
#                     "backend": backend
#                 })
#                 print(f"Found camera {camera_id} with backend {backend}")
#                 camera_found = True
#                 break
        
#         if not camera_found:
#             # หาก backends ทั้งหมดไม่ได้ผล หยุดการค้นหา
#             if camera_id > 2:  # อนุญาตให้หาไม่เจอได้ 3 ครั้งแรก
#                 break
    
#     print(f"Total cameras found: {len(available)}")
    
#     # หากไม่พบกล้องใดเลย สร้าง virtual camera สำหรับทดสอบ
#     if not available:
#         available.append({
#             "id": 999,
#             "name": "Virtual Camera (Test)",
#             "backend": "virtual"
#         })
    
#     return jsonify(available)

# @app.route('/api/cameras/<int:camera_id>/start', methods=['POST'])
# def start_camera(camera_id):
#     print(f"Starting camera {camera_id}...")
    
#     # ถ้า camera กำลังทำงานอยู่แล้ว
#     if camera_id in camera_streams and camera_streams[camera_id].get('cap') and camera_streams[camera_id]['cap'].isOpened():
#         return jsonify({"success": True, "message": "Camera already started"}), 200

#     # สร้าง lock สำหรับ camera นี้
#     if camera_id not in camera_locks:
#         camera_locks[camera_id] = threading.Lock()

#     with camera_locks[camera_id]:
#         try:
#             # Virtual camera สำหรับทดสอบ
#             if camera_id == 999:
#                 camera_streams[camera_id] = {
#                     'cap': 'virtual',
#                     'active': True
#                 }
#                 return jsonify({"success": True, "message": "Virtual camera started"}), 200

#             # ลองเปิดกล้องด้วย backend ต่างๆ
#             backends = [cv2.CAP_DSHOW, cv2.CAP_MSMF, cv2.CAP_ANY]
#             cap = None
            
#             for backend in backends:
#                 try:
#                     temp_cap = cv2.VideoCapture(camera_id, backend)
#                     if temp_cap.isOpened():
#                         # ตั้งค่า properties
#                         temp_cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
#                         temp_cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
#                         temp_cap.set(cv2.CAP_PROP_FPS, 15)
#                         temp_cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
                        
#                         # ทดสอบอ่านเฟรม
#                         ret, frame = temp_cap.read()
#                         if ret and frame is not None:
#                             cap = temp_cap
#                             print(f"Camera {camera_id} opened successfully with backend {backend}")
#                             break
#                         else:
#                             temp_cap.release()
#                     else:
#                         if temp_cap:
#                             temp_cap.release()
#                 except Exception as e:
#                     print(f"Failed to open camera {camera_id} with backend {backend}: {e}")
#                     if temp_cap:
#                         temp_cap.release()

#             if not cap:
#                 return jsonify({"success": False, "message": "Unable to open camera"}), 500

#             camera_streams[camera_id] = {
#                 'cap': cap,
#                 'active': True
#             }
            
#             return jsonify({"success": True, "message": "Camera started successfully"}), 200

#         except Exception as e:
#             print(f"Error starting camera {camera_id}: {e}")
#             return jsonify({"success": False, "message": f"Error: {str(e)}"}), 500

# @app.route('/api/cameras/<int:camera_id>/stop', methods=['POST'])
# def stop_camera(camera_id):
#     print(f"Stopping camera {camera_id}...")
    
#     if camera_id not in camera_streams:
#         return jsonify({"success": False, "message": "Camera not running"}), 400

#     if camera_id in camera_locks:
#         with camera_locks[camera_id]:
#             stream_info = camera_streams.get(camera_id)
#             if stream_info:
#                 if stream_info['cap'] != 'virtual' and hasattr(stream_info['cap'], 'release'):
#                     stream_info['cap'].release()
#                 del camera_streams[camera_id]
#                 return jsonify({"success": True, "message": "Camera stopped"}), 200
    
#     return jsonify({"success": False, "message": "Camera not running"}), 400

# @app.route('/api/cameras/<int:camera_id>/status', methods=['GET'])
# def camera_status(camera_id):
#     stream_info = camera_streams.get(camera_id)
#     if not stream_info:
#         return jsonify({"active": False}), 200
    
#     if stream_info['cap'] == 'virtual':
#         return jsonify({"active": stream_info.get('active', False)}), 200
    
#     active = stream_info['cap'] and stream_info['cap'].isOpened()
#     return jsonify({"active": active}), 200

# def generate_virtual_frame():
#     """สร้างเฟรมสำหรับ virtual camera"""
#     import numpy as np
    
#     # สร้างภาพสีดำขนาด 640x480
#     frame = np.zeros((480, 640, 3), dtype=np.uint8)
    
#     # เพิ่มข้อความ
#     font = cv2.FONT_HERSHEY_SIMPLEX
#     text = f"Virtual Camera - {time.strftime('%H:%M:%S')}"
#     text_size = cv2.getTextSize(text, font, 1, 2)[0]
#     text_x = (frame.shape[1] - text_size[0]) // 2
#     text_y = (frame.shape[0] + text_size[1]) // 2
    
#     cv2.putText(frame, text, (text_x, text_y), font, 1, (0, 255, 0), 2)
    
#     # เพิ่มเวลาที่มุมขวาบน
#     time_text = time.strftime('%Y-%m-%d %H:%M:%S')
#     cv2.putText(frame, time_text, (10, 30), font, 0.7, (255, 255, 255), 2)
    
#     return frame

# @app.route('/video/<int:camera_id>')
# def stream_camera(camera_id):
#     print(f"Video stream requested for camera {camera_id}")
    
#     def generate():
#         stream_info = camera_streams.get(camera_id)
#         if not stream_info:
#             print(f"Camera {camera_id} not found in streams")
#             return

#         try:
#             while True:
#                 if camera_id == 999:  # Virtual camera
#                     frame = generate_virtual_frame()
#                     success = True
#                 else:
#                     cap = stream_info['cap']
#                     if not cap or not cap.isOpened():
#                         print(f"Camera {camera_id} is not opened")
#                         break
                    
#                     success, frame = cap.read()
                
#                 if not success:
#                     print(f"Failed to read frame from camera {camera_id}")
#                     break

#                 # Encode frame
#                 ret, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 70])
#                 if not ret:
#                     print(f"Failed to encode frame from camera {camera_id}")
#                     continue
                
#                 frame_bytes = buffer.tobytes()
                
#                 yield (b'--frame\r\n'
#                        b'Content-Type: image/jpeg\r\n'
#                        b'Content-Length: ' + str(len(frame_bytes)).encode() + b'\r\n\r\n' + 
#                        frame_bytes + b'\r\n')
                
#                 # เพิ่ม delay เล็กน้อยเพื่อลด CPU usage
#                 time.sleep(0.033)  # ~30 FPS
                
#         except Exception as e:
#             print(f"Error in video stream for camera {camera_id}: {e}")

#     return Response(generate(), 
#                    mimetype='multipart/x-mixed-replace; boundary=frame',
#                    headers={'Cache-Control': 'no-cache, no-store, must-revalidate',
#                            'Pragma': 'no-cache',
#                            'Expires': '0'})

# # Cleanup when shutting down
# @app.teardown_appcontext
# def cleanup_cameras(error):
#     for camera_id, stream_info in camera_streams.items():
#         if stream_info['cap'] != 'virtual' and hasattr(stream_info['cap'], 'release'):
#             stream_info['cap'].release()

# --------------------

if __name__ == "__main__":
    app.run(debug=True, port=5000, threaded=True)